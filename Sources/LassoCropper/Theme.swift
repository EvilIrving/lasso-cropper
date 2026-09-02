import AppKit

enum Theme {
    static let lacquer = NSColor(srgbRed: 0.086, green: 0.078, blue: 0.067, alpha: 1)
    static let lacquerDeep = NSColor(srgbRed: 0.043, green: 0.039, blue: 0.033, alpha: 1)
    static let raised = NSColor(srgbRed: 0.125, green: 0.114, blue: 0.098, alpha: 1)
    static let graphite = NSColor(srgbRed: 0.165, green: 0.153, blue: 0.133, alpha: 1)
    static let gold = NSColor(srgbRed: 0.925, green: 0.722, blue: 0.275, alpha: 1)
    static let goldRich = NSColor(srgbRed: 0.78, green: 0.58, blue: 0.18, alpha: 1)
    static let goldPale = NSColor(srgbRed: 0.94, green: 0.82, blue: 0.52, alpha: 1)
    static let ink = NSColor(srgbRed: 0.12, green: 0.09, blue: 0.05, alpha: 1)
    static let champagne = NSColor(srgbRed: 0.93, green: 0.925, blue: 0.91, alpha: 1)
    static let muted = NSColor(srgbRed: 0.70, green: 0.68, blue: 0.64, alpha: 1)
    static let faint = NSColor(srgbRed: 0.52, green: 0.50, blue: 0.46, alpha: 1)
    static let hairline = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    static let goldLine = NSColor(srgbRed: 0.78, green: 0.58, blue: 0.18, alpha: 0.62)
    static let patina = NSColor(srgbRed: 0.38, green: 0.70, blue: 0.67, alpha: 1)

    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, tracking: CGFloat = 0) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.drawsBackground = false
        field.isBezeled = false
        if tracking != 0 {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: field.font as Any,
                .foregroundColor: color,
                .kern: tracking
            ]
            field.attributedStringValue = NSAttributedString(string: text, attributes: attributes)
        }
        return field
    }
}

final class HairlineView: NSView {
    var color: NSColor = Theme.hairline

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        bounds.fill()
    }
}

final class GoldButton: NSButton {
    override var isEnabled: Bool {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill = isEnabled ? (isHighlighted ? Theme.goldPale : Theme.gold) : Theme.graphite
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
        fill.setFill()
        path.fill()
        let text = title as NSString
        let color = isEnabled ? Theme.ink : Theme.faint
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 - 1),
            withAttributes: attributes
        )
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 88, height: 28) }
}

final class GhostButton: NSButton {
    override func awakeFromNib() { super.awakeFromNib(); restyle() }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        restyle()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        restyle()
    }

    private func restyle() {
        isBordered = false
        imagePosition = .imageLeading
        contentTintColor = Theme.champagne
        font = .systemFont(ofSize: 13, weight: .medium)
    }
}

final class FilmRow: NSView {
    var indexTitle = ""
    var preview: NSImage?
    var selected = false
    var onSelect: (() -> Void)?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            Theme.gold.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 2), xRadius: 2, yRadius: 2).fill()
        }
        let thumb = NSRect(x: 12, y: 8, width: 48, height: 48)
        Theme.lacquerDeep.setFill()
        thumb.fill()
        (selected ? Theme.goldLine : Theme.hairline).setStroke()
        NSBezierPath.stroke(thumb.insetBy(dx: 0.5, dy: 0.5))
        preview?.draw(in: thumb, from: .zero, operation: .sourceOver, fraction: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: selected ? Theme.gold : Theme.muted,
            .kern: 0.6
        ]
        (indexTitle as NSString).draw(at: CGPoint(x: 70, y: 24), withAttributes: attributes)
    }
}

final class EmptyDropView: NSView {
    var visible = true {
        didSet { isHidden = !visible }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.lacquerDeep.setFill()
        bounds.fill()
        let frame = NSRect(
            x: (bounds.width - 320) / 2,
            y: (bounds.height - 160) / 2,
            width: 320,
            height: 160
        )
        let path = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
        path.lineWidth = 1
        path.setLineDash([5, 4], count: 2, phase: 0)
        Theme.goldLine.setStroke()
        path.stroke()
        let title = "打开或拖入图片" as NSString
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: Theme.champagne
        ]
        let titleSize = title.size(withAttributes: titleAttr)
        title.draw(
            at: CGPoint(x: bounds.midX - titleSize.width / 2, y: bounds.midY - 18),
            withAttributes: titleAttr
        )
        let sub = "PNG · JPEG · HEIC · WebP" as NSString
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: Theme.faint,
            .kern: 1.2
        ]
        let subSize = sub.size(withAttributes: subAttr)
        sub.draw(
            at: CGPoint(x: bounds.midX - subSize.width / 2, y: bounds.midY + 8),
            withAttributes: subAttr
        )
    }
}
