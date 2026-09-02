import AppKit

struct OverlayCut {
    var points: [CGPoint]
    var label: String
    var selected: Bool
}

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

final class LassoScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let wantsZoom =
            modifiers.contains(.control) ||
            modifiers.contains(.command) ||
            isMouseWheel(event)
        if wantsZoom, event.scrollingDeltaY != 0 {
            zoom(at: event)
            return
        }
        super.scrollWheel(with: event)
    }

    private func isMouseWheel(_ event: NSEvent) -> Bool {
        event.phase.isEmpty &&
            event.momentumPhase.isEmpty &&
            !event.hasPreciseScrollingDeltas
    }

    private func zoom(at event: NSEvent) {
        let point = documentView?.convert(event.locationInWindow, from: nil)
            ?? contentView.convert(event.locationInWindow, from: nil)
        let steps = max(abs(event.scrollingDeltaY), 1)
        var factor = pow(1.08, steps)
        if event.scrollingDeltaY < 0 { factor = 1 / factor }
        let next = min(maxMagnification, max(minMagnification, magnification * factor))
        setMagnification(next, centeredAt: point)
    }
}

final class LassoCanvasView: NSView {
    var sourceImage: CGImage? {
        didSet {
            livePoints.removeAll()
            isDrawing = false
            if let sourceImage {
                setFrameSize(NSSize(width: sourceImage.width, height: sourceImage.height))
            } else {
                setFrameSize(NSSize(width: 800, height: 600))
            }
            needsDisplay = true
        }
    }

    var overlays: [OverlayCut] = [] {
        didSet { needsDisplay = true }
    }

    var allowsDrawing = false
    var spaceDown = false {
        didSet {
            window?.invalidateCursorRects(for: self)
            if spaceDown { NSCursor.openHand.set() } else { drawingCursor.set() }
        }
    }

    var onCommit: ((LassoCut) -> Void)?
    var onSelectOverlay: ((Int) -> Void)?
    var onDeleteOverlay: ((Int) -> Void)?
    var onOpenURL: ((URL) -> Void)?

    private var livePoints: [CGPoint] = []
    private var isDrawing = false
    private var isPanning = false
    private var lastWindowPoint: NSPoint = .zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { frame.size }

    private var magnification: CGFloat {
        max(0.08, enclosingScrollView?.magnification ?? 1)
    }

    private var drawingCursor: NSCursor { .crosshair }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: spaceDown ? .openHand : drawingCursor)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(Theme.lacquerDeep.cgColor)
        context.fill(bounds)

        guard let sourceImage else { return }
        drawCheckerboard(in: bounds, context: context)
        context.saveGState()
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(sourceImage, in: bounds)
        context.restoreGState()

        let line = max(1, 2 / magnification)
        for overlay in overlays {
            let color = overlay.selected ? Theme.gold : Theme.goldRich
            drawPath(overlay.points, in: context, fill: overlay.selected, color: color, lineWidth: line)
            if overlay.selected {
                drawBadge(overlay.label, at: overlay.points.isEmpty ? .zero : centroid(overlay.points), in: context)
            }
        }
        if livePoints.count > 1 {
            drawPath(livePoints, in: context, fill: false, color: Theme.goldPale, lineWidth: line)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = clamped(convert(event.locationInWindow, from: nil))
        if spaceDown {
            isPanning = true
            lastWindowPoint = event.locationInWindow
            NSCursor.closedHand.set()
            return
        }
        if event.modifierFlags.contains(.option), let index = overlayIndex(at: point) {
            onDeleteOverlay?(index)
            return
        }
        if let index = overlayIndex(at: point) {
            onSelectOverlay?(index)
            return
        }
        guard allowsDrawing else { return }
        livePoints = [point]
        isDrawing = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if isPanning, let scroll = enclosingScrollView {
            let now = event.locationInWindow
            var origin = scroll.contentView.bounds.origin
            origin.x -= (now.x - lastWindowPoint.x)
            origin.y += (now.y - lastWindowPoint.y)
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
            lastWindowPoint = now
            return
        }
        guard isDrawing else { return }
        let point = clamped(convert(event.locationInWindow, from: nil))
        guard let last = livePoints.last else { return }
        if hypot(point.x - last.x, point.y - last.y) >= 0.7 {
            livePoints.append(point)
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            isPanning = false
            NSCursor.openHand.set()
            return
        }
        guard isDrawing else { return }
        let point = clamped(convert(event.locationInWindow, from: nil))
        if let last = livePoints.last, hypot(point.x - last.x, point.y - last.y) >= 0.7 {
            livePoints.append(point)
        }
        isDrawing = false
        let cut = LassoCut(points: livePoints)
        livePoints.removeAll()
        needsDisplay = true
        if cut.isUsable {
            onCommit?(cut)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            livePoints.removeAll()
            isDrawing = false
            needsDisplay = true
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        imageURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = imageURL(from: sender) else { return false }
        onOpenURL?(url)
        return true
    }

    private func overlayIndex(at point: CGPoint) -> Int? {
        overlays.lastIndex(where: { LassoCut(points: $0.points).contains(point) })
    }

    private func centroid(_ points: [CGPoint]) -> CGPoint {
        LassoCut(points: points).centroid
    }

    private func drawPath(_ points: [CGPoint], in context: CGContext, fill: Bool, color: NSColor, lineWidth: CGFloat) {
        guard points.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        if fill {
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color.withAlphaComponent(0.16).cgColor)
            context.fillPath()
        }
        context.addPath(path)
        context.setStrokeColor(color.withAlphaComponent(fill ? 1 : 0.7).cgColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.strokePath()
    }

    private func drawBadge(_ text: String, at point: CGPoint, in context: CGContext) {
        let font = NSFont.boldSystemFont(ofSize: max(9, 11 / magnification))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let nsText = text as NSString
        let textSize = nsText.size(withAttributes: attributes)
        let padding = 6 / magnification
        let rect = CGRect(
            x: point.x - (textSize.width / 2) - padding,
            y: point.y - (textSize.height / 2) - padding / 2,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        context.setFillColor(Theme.gold.cgColor)
        context.fill(rect)
        nsText.draw(
            at: CGPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2),
            withAttributes: attributes
        )
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(0, point.x), bounds.width),
            y: min(max(0, point.y), bounds.height)
        )
    }

    private func drawCheckerboard(in rect: CGRect, context: CGContext) {
        let cell: CGFloat = 16
        let light = NSColor(srgbRed: 0.18, green: 0.16, blue: 0.14, alpha: 1).cgColor
        let dark = NSColor(srgbRed: 0.12, green: 0.11, blue: 0.09, alpha: 1).cgColor
        var row = 0
        var y: CGFloat = 0
        while y < rect.height {
            var column = 0
            var x: CGFloat = 0
            while x < rect.width {
                context.setFillColor((row + column).isMultiple(of: 2) ? light : dark)
                context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                x += cell
                column += 1
            }
            y += cell
            row += 1
        }
    }

    private func imageURL(from sender: NSDraggingInfo) -> URL? {
        guard let items = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return nil }
        return items.first(where: { NSImage(contentsOf: $0) != nil })
    }
}

final class PreviewView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let cell: CGFloat = 10
        var row = 0
        var y: CGFloat = 0
        while y < bounds.height {
            var column = 0
            var x: CGFloat = 0
            while x < bounds.width {
                ((row + column).isMultiple(of: 2) ? NSColor(srgbRed: 0.22, green: 0.20, blue: 0.17, alpha: 1) : NSColor(srgbRed: 0.16, green: 0.15, blue: 0.13, alpha: 1)).setFill()
                NSBezierPath.fill(CGRect(x: x, y: y, width: cell, height: cell))
                x += cell
                column += 1
            }
            y += cell
            row += 1
        }
        NSColor.separatorColor.setStroke()
        NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        guard let image else { return }
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
