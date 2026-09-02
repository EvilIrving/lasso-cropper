import AppKit

@MainActor
final class LassoViewController: NSViewController, NSPathControlDelegate {
    var pendingURL: URL?

    private let canvas = LassoCanvasView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    private let scrollView = LassoScrollView()
    private let preview = PreviewView()
    private let previewTitle = NSTextField(labelWithString: "未圈选")
    private let previewMeta = NSTextField(labelWithString: "")
    private let listStack = NSStackView()
    private let listScroll = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "打开或拖入图片")
    private let nextLabel = NSTextField(labelWithString: "")
    private let destinationControl = NSPathControl()
    private let canvasPopup = NSPopUpButton()
    private let marginSlider = NSSlider(value: Defaults.marginPercent, minValue: 0, maxValue: 20, target: nil, action: nil)
    private let marginValue = NSTextField(labelWithString: "")
    private let jobBar = NSStackView()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let exportButton = GoldButton(title: "导出", target: nil, action: nil)
    private let emptyDrop = EmptyDropView()
    private let changeFolderButton = NSButton()

    private var sourceURL: URL?
    private var sourceImage: CGImage?
    private var destination: URL?
    private var destinationAccessing = false
    private var slots: [Slot] = []
    private var selectedIndex = 0
    private var undoStack: [(slots: [Slot], selected: Int)] = []
    private var redoStack: [(slots: [Slot], selected: Int)] = []
    private var didAppear = false
    private var spaceMonitor: Any?
    private var saveWork: DispatchWorkItem?

    private var canvasSize: Int = Defaults.canvasSize {
        didSet { Defaults.canvasSize = canvasSize }
    }
    private var marginPercent: Double = Defaults.marginPercent {
        didSet { Defaults.marginPercent = marginPercent }
    }

    override func loadView() {
        view = NSView()
        view.setContentHuggingPriority(.init(1), for: .horizontal)
        view.setContentHuggingPriority(.init(1), for: .vertical)
        buildInterface()
        canvas.onCommit = { [weak self] cut in self?.commit(cut) }
        canvas.onSelectOverlay = { [weak self] index in self?.selectOverlay(index) }
        canvas.onDeleteOverlay = { [weak self] index in self?.deleteOverlay(index) }
        canvas.onOpenURL = { [weak self] url in self?.open(url: url) }
        spaceMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, event.keyCode == 49, !event.isARepeat else { return event }
            if event.charactersIgnoringModifiers == " " {
                self.canvas.spaceDown = event.type == .keyDown
                return nil
            }
            return event
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let spaceMonitor {
            NSEvent.removeMonitor(spaceMonitor)
            self.spaceMonitor = nil
        }
        releaseDestinationAccess()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didAppear else { return }
        didAppear = true
        if let pendingURL {
            open(url: pendingURL)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 {
            deleteSelected()
            return
        }
        super.keyDown(with: event)
    }

    private func buildInterface() {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = Theme.lacquer.cgColor

        let openButton = labeledButton("打开", symbol: "folder", action: #selector(openImage(_:)))
        let newButton = labeledButton("新窗口", symbol: "plus.rectangle.on.rectangle", action: #selector(newWindow(_:)))
        styleGhost(undoButton, title: "撤销", symbol: "arrow.uturn.backward")
        undoButton.target = self
        undoButton.action = #selector(undoAction(_:))
        undoButton.isEnabled = false
        styleGhost(redoButton, title: "重做", symbol: "arrow.uturn.forward")
        redoButton.target = self
        redoButton.action = #selector(redoAction(_:))
        redoButton.isEnabled = false

        let zoomOut = iconButton("minus.magnifyingglass", "缩小", #selector(zoomOut(_:)))
        let fit = iconButton("arrow.up.left.and.arrow.down.right", "适合窗口", #selector(fitImage(_:)))
        let zoomIn = iconButton("plus.magnifyingglass", "放大", #selector(zoomIn(_:)))

        canvasPopup.removeAllItems()
        canvasPopup.addItems(withTitles: ["256 × 256", "512 × 512", "1024 × 1024"])
        canvasPopup.selectItem(withTitle: "\(canvasSize) × \(canvasSize)")
        canvasPopup.target = self
        canvasPopup.action = #selector(canvasSizeChanged(_:))
        canvasPopup.toolTip = "每张导出 PNG 的正方形边长，图标会等比放进这块透明画布"

        marginSlider.target = self
        marginSlider.action = #selector(marginChanged(_:))
        marginSlider.toolTip = "透明画布四周留白"
        marginValue.stringValue = "\(Int(marginPercent))%"
        marginValue.alignment = .right
        marginValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        marginValue.textColor = Theme.champagne

        exportButton.target = self
        exportButton.action = #selector(exportAll(_:))
        exportButton.isEnabled = false
        exportButton.isBordered = false
        exportButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        exportButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let canvasLabel = Theme.label("画布", size: 11, weight: .medium, color: Theme.muted, tracking: 0.8)
        let marginLabel = Theme.label("边距", size: 11, weight: .medium, color: Theme.muted, tracking: 0.8)
        let flexible = NSView()
        flexible.setContentHuggingPriority(.defaultLow, for: .horizontal)

        [openButton, newButton, divider(), undoButton, redoButton, divider(), zoomOut, fit, zoomIn, flexible,
         canvasLabel, canvasPopup, marginLabel, marginSlider, marginValue, exportButton]
            .forEach(toolbar.addArrangedSubview)

        jobBar.orientation = .horizontal
        jobBar.alignment = .centerY
        jobBar.spacing = 10
        jobBar.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 8, right: 14)
        jobBar.translatesAutoresizingMaskIntoConstraints = false
        jobBar.wantsLayer = true
        jobBar.layer?.backgroundColor = Theme.lacquer.cgColor

        destinationControl.pathStyle = .popUp
        destinationControl.delegate = self
        destinationControl.placeholderString = "导出文件夹"
        destinationControl.target = self
        destinationControl.action = #selector(destinationChanged(_:))
        destinationControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        destinationControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        changeFolderButton.title = "更改"
        changeFolderButton.target = self
        changeFolderButton.action = #selector(chooseFolder(_:))
        changeFolderButton.isBordered = false
        changeFolderButton.font = .systemFont(ofSize: 12, weight: .medium)
        changeFolderButton.contentTintColor = Theme.gold
        statusLabel.textColor = Theme.muted
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nextLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        nextLabel.textColor = Theme.gold

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = canvas
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.12
        scrollView.maxMagnification = 12
        scrollView.backgroundColor = Theme.lacquerDeep
        scrollView.drawsBackground = true
        scrollView.borderType = .noBorder

        let sidebar = buildSidebar()
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        split.addArrangedSubview(scrollView)
        split.addArrangedSubview(sidebar)
        split.setHoldingPriority(NSLayoutConstraint.Priority(200), forSubviewAt: 0)
        split.setHoldingPriority(NSLayoutConstraint.Priority(400), forSubviewAt: 1)
        split.setContentHuggingPriority(.defaultLow, for: .vertical)
        split.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        view.addSubview(toolbar)
        view.addSubview(jobBar)
        view.addSubview(split)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            jobBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            jobBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            jobBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            jobBar.heightAnchor.constraint(equalToConstant: 34),
            split.topAnchor.constraint(equalTo: jobBar.bottomAnchor),
            split.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            split.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            split.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),
            sidebar.widthAnchor.constraint(equalToConstant: 268),
            marginSlider.widthAnchor.constraint(equalToConstant: 84),
            marginValue.widthAnchor.constraint(equalToConstant: 36),
            flexible.widthAnchor.constraint(greaterThanOrEqualToConstant: 8)
        ])
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.lacquer.cgColor
        emptyDrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyDrop)
        NSLayoutConstraint.activate([
            emptyDrop.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyDrop.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            emptyDrop.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            emptyDrop.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        refreshChrome()
    }

    private func buildSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = Theme.raised.cgColor
        preview.translatesAutoresizingMaskIntoConstraints = false
        previewTitle.font = .systemFont(ofSize: 13, weight: .medium)
        previewTitle.textColor = Theme.champagne
        previewMeta.textColor = Theme.muted
        previewMeta.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        previewMeta.lineBreakMode = .byTruncatingMiddle

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 2
        listStack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)
        listStack.translatesAutoresizingMaskIntoConstraints = false

        let clip = FlippedClipView()
        clip.drawsBackground = false
        listScroll.contentView = clip
        listScroll.documentView = listStack
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false
        listScroll.borderType = .noBorder
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: clip.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            listStack.widthAnchor.constraint(equalTo: clip.widthAnchor)
        ])

        sidebar.addSubview(preview)
        sidebar.addSubview(previewTitle)
        sidebar.addSubview(previewMeta)
        sidebar.addSubview(listScroll)
        previewTitle.translatesAutoresizingMaskIntoConstraints = false
        previewMeta.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 12),
            preview.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            preview.widthAnchor.constraint(equalToConstant: 168),
            preview.heightAnchor.constraint(equalToConstant: 168),
            previewTitle.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 8),
            previewTitle.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            previewTitle.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            previewMeta.topAnchor.constraint(equalTo: previewTitle.bottomAnchor, constant: 2),
            previewMeta.leadingAnchor.constraint(equalTo: previewTitle.leadingAnchor),
            previewMeta.trailingAnchor.constraint(equalTo: previewTitle.trailingAnchor),
            listScroll.topAnchor.constraint(equalTo: previewMeta.bottomAnchor, constant: 10),
            listScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            listScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            listScroll.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor)
        ])
        return sidebar
    }

    private func labeledButton(_ title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        styleGhost(button, title: title, symbol: symbol)
        return button
    }

    private func iconButton(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!,
            target: self,
            action: action
        )
        button.isBordered = false
        button.contentTintColor = Theme.champagne
        button.toolTip = tip
        return button
    }

    private func styleGhost(_ button: NSButton, title: String, symbol: String) {
        button.title = title
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.isBordered = false
        button.contentTintColor = Theme.champagne
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.toolTip = title
    }

    private func divider() -> NSView {
        let line = HairlineView()
        line.color = Theme.hairline
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        line.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return line
    }

    @objc func openImage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url: url)
    }

    func retryPending() {
        guard sourceImage == nil, let pendingURL else { return }
        open(url: pendingURL)
    }

    func open(url: URL) {
        pendingURL = url
        do {
            let image = try ImageLoading.load(url: url)
            sourceURL = url
            sourceImage = image
            canvas.sourceImage = image
            view.window?.title = "套索导出 — \(url.lastPathComponent)"
            undoStack.removeAll()
            redoStack.removeAll()
            if let session = SessionStore.load(source: url), session.source == url.standardizedFileURL.path {
                restore(session)
            } else {
                slots.removeAll()
                selectedIndex = 0
                adoptDestination(Defaults.lastDestination ?? JobFactory.defaultDestination(for: url), persistBookmark: false)
            }
            refreshAll()
            DispatchQueue.main.async { [weak self] in self?.fitImage(nil) }
        } catch {
            presentError(error)
        }
    }

    @objc func newWindow(_ sender: Any?) {
        AppDelegate.shared.createWindow(opening: nil)
    }

    @objc private func chooseFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "用作导出文件夹"
        panel.message = "选择后会记住此文件夹，下次无需重新授权"
        panel.directoryURL = destination
        guard panel.runModal() == .OK, let url = panel.url else { return }
        adoptDestination(url, persistBookmark: true)
        refreshChrome()
        persistSoon()
    }

    @objc private func destinationChanged(_ sender: Any?) {
        if let url = destinationControl.url {
            adoptDestination(url, persistBookmark: true)
            persistSoon()
        }
    }

    @objc private func canvasSizeChanged(_ sender: Any?) {
        let sizes = [256, 512, 1024]
        canvasSize = sizes[max(0, canvasPopup.indexOfSelectedItem)]
        rebuildPreviews()
        persistSoon()
    }

    @objc private func marginChanged(_ sender: Any?) {
        marginPercent = marginSlider.doubleValue.rounded()
        marginValue.stringValue = "\(Int(marginPercent))%"
        rebuildPreviews()
        persistSoon()
    }

    @objc func undoAction(_ sender: Any?) {
        guard let item = undoStack.popLast() else { return }
        redoStack.append((slots: slots, selected: selectedIndex))
        slots = item.slots
        selectedIndex = item.selected
        rebuildPreviews()
        refreshAll()
        persistSoon()
    }

    @objc func redoAction(_ sender: Any?) {
        guard let item = redoStack.popLast() else { return }
        undoStack.append((slots: slots, selected: selectedIndex))
        slots = item.slots
        selectedIndex = item.selected
        rebuildPreviews()
        refreshAll()
        persistSoon()
    }

    @objc func zoomIn(_ sender: Any?) {
        scrollView.setMagnification(min(scrollView.maxMagnification, scrollView.magnification * 1.25), centeredAt: visibleCenter)
    }

    @objc func zoomOut(_ sender: Any?) {
        scrollView.setMagnification(max(scrollView.minMagnification, scrollView.magnification / 1.25), centeredAt: visibleCenter)
    }

    @objc func fitImage(_ sender: Any?) {
        guard canvas.sourceImage != nil else { return }
        let viewport = scrollView.contentView.bounds.size
        guard viewport.width > 1, viewport.height > 1 else { return }
        let fit = min(viewport.width / canvas.bounds.width, viewport.height / canvas.bounds.height) * 0.96
        scrollView.magnification = min(max(fit, scrollView.minMagnification), scrollView.maxMagnification)
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc func exportAll(_ sender: Any?) {
        do {
            try performExport()
        } catch {
            presentError(error)
        }
    }

    private func commit(_ cut: LassoCut) {
        pushUndo()
        let name = String(format: "%02d", slots.count + 1)
        slots.append(Slot(spec: SlotSpec(folder: "", name: name), cut: cut, preview: nil))
        selectedIndex = slots.count - 1
        refreshPreview(at: selectedIndex)
        refreshAll()
        persistSoon()
    }

    private func pushUndo() {
        undoStack.append((slots: slots, selected: selectedIndex))
        redoStack.removeAll()
    }

    private func selectOverlay(_ overlayIndex: Int) {
        let filled = slots.indices.filter { slots[$0].cut != nil }
        guard filled.indices.contains(overlayIndex) else { return }
        selectedIndex = filled[overlayIndex]
        refreshAll()
    }

    private func deleteOverlay(_ overlayIndex: Int) {
        let filled = slots.indices.filter { slots[$0].cut != nil }
        guard filled.indices.contains(overlayIndex) else { return }
        selectedIndex = filled[overlayIndex]
        deleteSelected()
    }

    private func deleteSelected() {
        guard slots.indices.contains(selectedIndex) else { return }
        pushUndo()
        slots.remove(at: selectedIndex)
        for index in slots.indices {
            slots[index].spec.name = String(format: "%02d", index + 1)
        }
        selectedIndex = min(selectedIndex, max(0, slots.count - 1))
        refreshAll()
        persistSoon()
    }

    private func performExport() throws {
        guard sourceImage != nil else { throw LassoError.noImage }
        let filled = slots.filter { $0.cut != nil }
        guard !filled.isEmpty else { throw LassoError.noSelection }
        if destination == nil {
            chooseFolder(nil)
        }
        guard let destination, let sourceImage else { throw LassoError.noDestination }
        ensureDestinationAccess()
        if !canWrite(to: destination) {
            chooseFolder(nil)
            guard let destination = self.destination, canWrite(to: destination) else {
                throw LassoError.noDestination
            }
            try writeExports(filled: filled, sourceImage: sourceImage, destination: destination)
            return
        }
        try writeExports(filled: filled, sourceImage: sourceImage, destination: destination)
    }

    private func writeExports(filled: [Slot], sourceImage: CGImage, destination: URL) throws {
        let existing = filled.compactMap { slot -> String? in
            let url = destination.appendingPathComponent(slot.spec.folder).appendingPathComponent(slot.spec.fileName)
            return FileManager.default.fileExists(atPath: url.path) ? slot.spec.id : nil
        }
        if !existing.isEmpty {
            let alert = NSAlert()
            alert.messageText = "替换已有的 \(existing.count) 张图？"
            alert.informativeText = existing.prefix(6).joined(separator: "\n") + (existing.count > 6 ? "\n…" : "")
            alert.addButton(withTitle: "替换")
            alert.addButton(withTitle: "取消")
            if alert.runModal() != .alertFirstButtonReturn { return }
        }

        try SecurityScoped.access(destination) { scopedDestination in
            for slot in filled {
                guard let cut = slot.cut else { continue }
                let image = try LassoExport.render(
                    source: sourceImage,
                    cut: cut,
                    canvasSize: canvasSize,
                    marginPercent: marginPercent
                )
                let url = scopedDestination.appendingPathComponent(slot.spec.folder).appendingPathComponent(slot.spec.fileName)
                try LassoExport.write(image, to: url)
            }
            NSWorkspace.shared.open(scopedDestination)
        }
        statusLabel.stringValue = "已导出 \(filled.count) 张"
    }

    private func restore(_ session: LassoSession) {
        canvasSize = session.canvasSize
        marginPercent = session.marginPercent
        marginSlider.doubleValue = marginPercent
        marginValue.stringValue = "\(Int(marginPercent))%"
        canvasPopup.selectItem(withTitle: "\(canvasSize) × \(canvasSize)")
        if let remembered = Defaults.lastDestination {
            adoptDestination(remembered, persistBookmark: false)
        } else if let sourceURL {
            adoptDestination(JobFactory.defaultDestination(for: sourceURL), persistBookmark: false)
        } else if let path = session.destination {
            adoptDestination(URL(fileURLWithPath: path, isDirectory: true), persistBookmark: false)
        }
        slots = session.cuts.enumerated().map { index, item in
            Slot(
                spec: SlotSpec(folder: "", name: String(format: "%02d", index + 1)),
                cut: LassoCut(points: item.points),
                preview: nil
            )
        }
        selectedIndex = min(max(0, session.selectedIndex), max(0, slots.count - 1))
        rebuildPreviews()
    }

    private func adoptDestination(_ url: URL, persistBookmark: Bool) {
        releaseDestinationAccess()
        destination = url
        if persistBookmark {
            Defaults.lastDestination = url
        }
        ensureDestinationAccess()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func ensureDestinationAccess() {
        guard let destination, !destinationAccessing else { return }
        destinationAccessing = destination.startAccessingSecurityScopedResource()
    }

    private func releaseDestinationAccess() {
        guard destinationAccessing, let destination else {
            destinationAccessing = false
            return
        }
        destination.stopAccessingSecurityScopedResource()
        destinationAccessing = false
    }

    private func canWrite(to url: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            let probe = url.appendingPathComponent(".lasso-write-test")
            try Data().write(to: probe, options: .atomic)
            try? fm.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    private func persistSoon() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.persistNow() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func persistNow() {
        guard let sourceURL else { return }
        let cuts = slots.compactMap { slot -> LassoSession.PersistedCut? in
            guard let cut = slot.cut else { return nil }
            return LassoSession.PersistedCut(id: slot.spec.id, points: cut.points)
        }
        SessionStore.save(
            LassoSession(
                source: sourceURL.standardizedFileURL.path,
                destination: destination?.path,
                canvasSize: canvasSize,
                marginPercent: marginPercent,
                selectedIndex: selectedIndex,
                cuts: cuts
            ),
            source: sourceURL
        )
    }

    private func rebuildPreviews() {
        for index in slots.indices { refreshPreview(at: index) }
        refreshPreviewPane()
    }

    private func refreshPreview(at index: Int) {
        guard slots.indices.contains(index), let sourceImage, let cut = slots[index].cut else {
            if slots.indices.contains(index) { slots[index].preview = nil }
            return
        }
        slots[index].preview = LassoExport.previewImage(
            source: sourceImage,
            cut: cut,
            canvasSize: canvasSize,
            marginPercent: marginPercent
        )
    }

    private func refreshAll() {
        refreshChrome()
        refreshOverlays()
        refreshList()
        refreshPreviewPane()
    }

    private func refreshChrome() {
        let filled = slots.count
        canvas.allowsDrawing = sourceImage != nil
        emptyDrop.visible = sourceImage == nil
        undoButton.isEnabled = !undoStack.isEmpty
        redoButton.isEnabled = !redoStack.isEmpty
        exportButton.isEnabled = filled > 0 && destination != nil
        exportButton.title = filled == 0 ? "导出" : "导出 \(filled) 张"
        marginValue.stringValue = "\(Int(marginPercent))%"

        jobBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if sourceImage == nil {
            statusLabel.stringValue = "打开或拖入图片"
            jobBar.addArrangedSubview(statusLabel)
        } else {
            destinationControl.url = destination
            let destLabel = Theme.label("导出到", size: 11, weight: .medium, color: Theme.muted, tracking: 0.8)
            jobBar.addArrangedSubview(destLabel)
            jobBar.addArrangedSubview(destinationControl)
            jobBar.addArrangedSubview(changeFolderButton)
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            jobBar.addArrangedSubview(spacer)
            nextLabel.stringValue = "已圈 \(filled)"
            jobBar.addArrangedSubview(nextLabel)
            destinationControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
    }

    private func refreshOverlays() {
        canvas.overlays = slots.compactMap { slot in
            guard let cut = slot.cut else { return nil }
            return OverlayCut(
                points: cut.points,
                label: slot.spec.shortLabel,
                selected: slots.indices.contains(selectedIndex) && slot.spec.id == slots[selectedIndex].spec.id
            )
        }
    }

    private func refreshPreviewPane() {
        guard slots.indices.contains(selectedIndex) else {
            preview.image = nil
            previewTitle.stringValue = "未圈选"
            previewMeta.stringValue = canvasCaption(cut: nil)
            return
        }
        let slot = slots[selectedIndex]
        preview.image = slot.preview
        previewTitle.stringValue = slot.spec.id
        previewMeta.stringValue = canvasCaption(cut: slot.cut)
    }

    private func canvasCaption(cut: LassoCut?) -> String {
        if let cut {
            let box = cut.bounds
            return "圈选 \(Int(box.width))×\(Int(box.height))  →  画布 \(canvasSize)×\(canvasSize)"
        }
        return "画布 \(canvasSize)×\(canvasSize) 透明 PNG"
    }

    private func refreshList() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, slot) in slots.enumerated() {
            listStack.addArrangedSubview(rowView(index: index, slot: slot))
        }
    }

    private func rowView(index: Int, slot: Slot) -> NSView {
        let row = FilmRow()
        row.indexTitle = slot.spec.name
        row.preview = slot.preview
        row.selected = index == selectedIndex
        row.onSelect = { [weak self] in
            self?.selectedIndex = index
            self?.refreshAll()
        }
        row.heightAnchor.constraint(equalToConstant: 64).isActive = true
        row.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        return row
    }

    private var visibleCenter: CGPoint {
        CGPoint(x: scrollView.documentVisibleRect.midX, y: scrollView.documentVisibleRect.midY)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate!

    private var windows: [NSWindow] = []

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        installMenu()
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame LassoCropper.Main")
        let argument = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
        createWindow(opening: argument)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in windows {
            (window.contentViewController as? LassoViewController)?.retryPending()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let window = windows.first(where: { ($0.contentViewController as? LassoViewController) != nil && windowIsEmpty($0) }) {
                (window.contentViewController as? LassoViewController)?.open(url: url)
                window.makeKeyAndOrderFront(nil)
            } else {
                createWindow(opening: url)
            }
        }
    }

    func createWindow(opening url: URL?) {
        let controller = LassoViewController()
        controller.pendingURL = url
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "套索导出"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.lacquer
        window.titlebarAppearsTransparent = true
        window.contentViewController = controller
        window.minSize = NSSize(width: 880, height: 560)
        window.contentMinSize = NSSize(width: 880, height: 560)
        window.isReleasedWhenClosed = false
        window.delegate = self
        place(window)
        window.makeKeyAndOrderFront(nil)
        place(window)
        windows.append(window)
    }

    func windowWillClose(_ notification: Notification) {
        windows.removeAll { $0 === (notification.object as? NSWindow) }
    }

    private func windowIsEmpty(_ window: NSWindow) -> Bool {
        window.title == "套索导出"
    }

    private func place(_ window: NSWindow) {
        let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let width = min(1180, visible.width - 24)
        let height = min(780, visible.height - 24)
        let offset = CGFloat(windows.count * 26)
        let frame = NSRect(
            x: visible.minX + max(12, (visible.width - width) / 2) + offset,
            y: visible.minY + max(12, (visible.height - height) / 2) - offset,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
    }
}

@MainActor
func installMenu() {
    let mainMenu = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "隐藏套索导出", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let hideOthers = appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "退出套索导出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let fileItem = NSMenuItem()
    let fileMenu = NSMenu(title: "文件")
    fileMenu.addItem(withTitle: "打开…", action: #selector(LassoViewController.openImage(_:)), keyEquivalent: "o")
    fileMenu.addItem(withTitle: "新窗口", action: #selector(LassoViewController.newWindow(_:)), keyEquivalent: "n")
    fileMenu.addItem(NSMenuItem.separator())
    fileMenu.addItem(withTitle: "导出", action: #selector(LassoViewController.exportAll(_:)), keyEquivalent: "s")
    fileMenu.addItem(NSMenuItem.separator())
    fileMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    fileItem.submenu = fileMenu
    mainMenu.addItem(fileItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "编辑")
    editMenu.addItem(withTitle: "撤销", action: #selector(LassoViewController.undoAction(_:)), keyEquivalent: "z")
    let redo = editMenu.addItem(withTitle: "重做", action: #selector(LassoViewController.redoAction(_:)), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    let viewItem = NSMenuItem()
    let viewMenu = NSMenu(title: "显示")
    viewMenu.addItem(withTitle: "放大", action: #selector(LassoViewController.zoomIn(_:)), keyEquivalent: "=")
    viewMenu.addItem(withTitle: "缩小", action: #selector(LassoViewController.zoomOut(_:)), keyEquivalent: "-")
    viewMenu.addItem(withTitle: "适合窗口", action: #selector(LassoViewController.fitImage(_:)), keyEquivalent: "0")
    viewItem.submenu = viewMenu
    mainMenu.addItem(viewItem)

    NSApp.mainMenu = mainMenu
}
