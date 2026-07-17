import AppKit
import TubeCore

@MainActor
final class ServiceSwitcherController: NSWindowController, NSSearchFieldDelegate,
    NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate
{
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private var filteredServices = StreamingService.allCases
    private var selectedService = StreamingService.defaultService
    private weak var parentWindow: NSWindow?
    private var isDismissing = false

    var onSelectService: ((StreamingService) -> Void)?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    init() {
        let panel = ServiceSwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 310),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        panel.delegate = self
        configure(panel)
        installContent(in: panel)

        panel.onMoveSelection = { [weak self] offset in
            self?.moveSelection(by: offset)
        }
        panel.onConfirmSelection = { [weak self] in
            self?.confirmSelection()
        }
        panel.onCancel = { [weak self] in
            self?.dismiss()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(relativeTo parentWindow: NSWindow, selectedService: StreamingService) {
        self.selectedService = selectedService
        searchField.stringValue = ""
        filteredServices = StreamingService.allCases
        tableView.reloadData()
        selectCurrentServiceOrFirstResult()

        if let existingParent = self.parentWindow, existingParent !== parentWindow {
            existingParent.removeChildWindow(window!)
        }

        self.parentWindow = parentWindow

        guard let panel = window else {
            return
        }

        let origin = NSPoint(
            x: parentWindow.frame.midX - panel.frame.width / 2,
            y: parentWindow.frame.midY - panel.frame.height / 2 + 60
        )
        panel.setFrameOrigin(origin)

        if panel.parent !== parentWindow {
            parentWindow.addChildWindow(panel, ordered: .above)
        }

        showWindow(nil)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func dismiss() {
        guard let panel = window, !isDismissing else {
            return
        }

        isDismissing = true
        let parentWindow = parentWindow
        parentWindow?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.parentWindow = nil
        isDismissing = false

        if NSApp.isActive, parentWindow?.isVisible == true {
            parentWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let resignedWindow = notification.object as? NSWindow,
              resignedWindow === window,
              window?.isVisible == true
        else {
            return
        }

        dismiss()
    }

    func controlTextDidChange(_ notification: Notification) {
        let query = searchField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        filteredServices = query.isEmpty
            ? StreamingService.allCases
            : StreamingService.allCases.filter { service in
                service.displayName.lowercased().contains(query)
            }

        tableView.reloadData()
        selectCurrentServiceOrFirstResult()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredServices.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard filteredServices.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("StreamingServiceRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self)
            as? StreamingServiceRowView ?? StreamingServiceRowView(identifier: identifier)
        let service = filteredServices[row]
        rowView.update(service: service, isCurrent: service == selectedService)
        return rowView
    }

    private func configure(_ panel: ServiceSwitcherPanel) {
        panel.title = "Switch Service"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow
        panel.level = .floating
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.setAccessibilityLabel("Switch streaming service")
    }

    private func installContent(in panel: NSPanel) {
        let contentView = NSVisualEffectView()
        contentView.material = .popover
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        panel.contentView = contentView

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Switch service"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.setAccessibilityLabel("Search streaming services")

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Service"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.setAccessibilityLabel("Streaming services")

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func selectCurrentServiceOrFirstResult() {
        guard !filteredServices.isEmpty else {
            tableView.deselectAll(nil)
            return
        }

        let row = filteredServices.firstIndex(of: selectedService) ?? 0
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func moveSelection(by offset: Int) {
        guard !filteredServices.isEmpty else {
            return
        }

        let currentRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let row = min(max(currentRow + offset, 0), filteredServices.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func confirmSelection() {
        guard filteredServices.indices.contains(tableView.selectedRow) else {
            return
        }

        let service = filteredServices[tableView.selectedRow]
        dismiss()
        onSelectService?(service)
    }

    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        guard sender.clickedRow >= 0 else {
            return
        }

        sender.selectRowIndexes(IndexSet(integer: sender.clickedRow), byExtendingSelection: false)
        confirmSelection()
    }
}

private final class ServiceSwitcherPanel: NSPanel {
    var onMoveSelection: ((Int) -> Void)?
    var onConfirmSelection: (() -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }

        switch event.keyCode {
        case 125:
            onMoveSelection?(1)
        case 126:
            onMoveSelection?(-1)
        case 36, 76:
            onConfirmSelection?()
        case 53:
            onCancel?()
        default:
            super.sendEvent(event)
        }
    }
}

private final class StreamingServiceRowView: NSTableCellView {
    private let serviceImageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let currentLabel = NSTextField(labelWithString: "Current")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        serviceImageView.translatesAutoresizingMaskIntoConstraints = false
        serviceImageView.imageScaling = .scaleProportionallyDown
        serviceImageView.contentTintColor = .secondaryLabelColor

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail

        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        currentLabel.font = .systemFont(ofSize: 11, weight: .medium)
        currentLabel.textColor = .secondaryLabelColor

        addSubview(serviceImageView)
        addSubview(nameLabel)
        addSubview(currentLabel)

        NSLayoutConstraint.activate([
            serviceImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            serviceImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            serviceImageView.widthAnchor.constraint(equalToConstant: 22),
            serviceImageView.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: serviceImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            currentLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 12),
            currentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            currentLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(service: StreamingService, isCurrent: Bool) {
        nameLabel.stringValue = service.displayName
        currentLabel.isHidden = !isCurrent
        serviceImageView.image = NSImage(
            systemSymbolName: service.systemSymbolName,
            accessibilityDescription: service.displayName
        )
        setAccessibilityLabel("\(service.displayName)\(isCurrent ? ", current service" : "")")
    }
}

private extension StreamingService {
    var systemSymbolName: String {
        switch self {
        case .youtube:
            "play.rectangle.fill"
        case .youtubeTV:
            "tv.fill"
        case .netflix:
            "film.stack.fill"
        case .appleTV:
            "appletv.fill"
        case .hulu:
            "play.tv.fill"
        }
    }
}
