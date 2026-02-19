import Cocoa
import Combine

// MARK: - MainWindowController

class MainWindowController: NSWindowController, NSWindowDelegate {

    init(viewController: MainViewController) {
        let window = NSWindow(contentViewController: viewController)
        window.title = "Hangul Key Changer"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 340, height: 10))
        window.center()
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func showAndActivate() {
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }
}

// MARK: - MainViewController

class MainViewController: NSViewController {

    private let manager = KeyMappingManager.shared
    private var cancellables = Set<AnyCancellable>()

    // UI elements that need updating
    private var keyLabel: NSTextField!
    private var changeKeyButton: NSButton!
    private var statusIcon: NSImageView!
    private var statusLabel: NSTextField!
    private var toggleButton: NSButton!
    private var errorLabel: NSTextField!
    private var cardView: NSStackView!

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        bindManager()
        Task { await manager.checkCurrentStatus() }
    }

    // MARK: - Build UI

    private func buildUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainStack.widthAnchor.constraint(equalToConstant: 340),
        ])

        // 1. Header
        mainStack.addArrangedSubview(buildHeader())

        // 2. Divider
        mainStack.addArrangedSubview(makeDivider())

        // 3. Card (key config + status + toggle + instructions + error)
        let card = buildCard()
        mainStack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true

        // 4. Instructions
        let instructions = buildInstructions()
        mainStack.addArrangedSubview(instructions)
        instructions.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true

        // 5. Error label
        errorLabel = makeLabel("", size: 11, color: .systemRed)
        errorLabel.isHidden = true
        mainStack.addArrangedSubview(errorLabel)

        // 6. Divider + Donate
        mainStack.addArrangedSubview(makeDivider())
        let donateButton = buildDonateButton()
        mainStack.addArrangedSubview(donateButton)
        donateButton.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
    }

    // MARK: - Header

    private func buildHeader() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let title = makeLabel("Hangul Key Changer", size: 17, weight: .bold)
        let subtitle = makeLabel(String(localized: "app.subtitle"), size: 12, color: .secondaryLabelColor)

        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(titleStack)

        return stack
    }

    // MARK: - Card (Key + Status + Toggle)

    private func buildCard() -> NSView {
        cardView = NSStackView()
        let card = cardView!
        card.orientation = .vertical
        card.spacing = 14
        card.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10

        // Key selection row
        let keyRow = NSStackView()
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = 8

        let keyIcon = NSImageView()
        keyIcon.image = NSImage(systemSymbolName: "command", accessibilityDescription: nil)
        keyIcon.contentTintColor = .secondaryLabelColor
        keyIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        keyIcon.setContentHuggingPriority(.required, for: .horizontal)

        let keyTitle = makeLabel(String(localized: "key.switch"), size: 12, color: .secondaryLabelColor)
        keyTitle.setContentHuggingPriority(.required, for: .horizontal)

        keyLabel = makeLabel(manager.sourceKeyInfo.displayName, size: 13, weight: .medium)
        keyLabel.alignment = .right
        keyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        changeKeyButton = NSButton(title: String(localized: "button.change"), target: self, action: #selector(changeKeyTapped))
        changeKeyButton.bezelStyle = .rounded
        changeKeyButton.controlSize = .small
        changeKeyButton.setContentHuggingPriority(.required, for: .horizontal)

        keyRow.addArrangedSubview(keyIcon)
        keyRow.addArrangedSubview(keyTitle)
        keyRow.addArrangedSubview(keyLabel)
        keyRow.addArrangedSubview(changeKeyButton)

        card.addArrangedSubview(keyRow)
        keyRow.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28).isActive = true

        // Divider in card
        card.addArrangedSubview(makeDivider())

        // Status row
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 4

        statusIcon = NSImageView()
        statusIcon.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        statusIcon.contentTintColor = .systemGray
        statusIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        statusIcon.setContentHuggingPriority(.required, for: .horizontal)

        let statusTitle = makeLabel(String(localized: "status"), size: 12, color: .secondaryLabelColor)
        statusTitle.setContentHuggingPriority(.required, for: .horizontal)

        statusLabel = makeLabel(String(localized: "status.disabled"), size: 13, weight: .medium)
        statusLabel.textColor = .systemRed
        statusLabel.alignment = .right

        statusRow.addArrangedSubview(statusIcon)
        statusRow.addArrangedSubview(statusTitle)
        statusRow.addArrangedSubview(statusLabel)

        card.addArrangedSubview(statusRow)
        statusRow.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28).isActive = true

        // Toggle button
        toggleButton = NSButton(title: String(localized: "button.enable"), target: self, action: #selector(toggleTapped))
        toggleButton.bezelStyle = .rounded
        toggleButton.isBordered = false
        toggleButton.wantsLayer = true
        toggleButton.layer?.cornerRadius = 8
        toggleButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        toggleButton.contentTintColor = .white
        toggleButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        toggleButton.alignment = .center

        card.addArrangedSubview(toggleButton)
        toggleButton.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28).isActive = true
        toggleButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        return card
    }

    // MARK: - Instructions

    private func buildInstructions() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let sectionTitle = makeLabel(String(localized: "instructions.title"), size: 12, weight: .semibold)
        stack.addArrangedSubview(sectionTitle)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6

        rows.addArrangedSubview(makeInstructionRow(number: 1, text: String(localized: "instructions.step1")))
        rows.addArrangedSubview(makeInstructionRow(number: 2, text: String(localized: "instructions.step2")))
        stack.addArrangedSubview(rows)

        let note = makeLabel(
            String(localized: "instructions.note"),
            size: 10,
            color: .secondaryLabelColor
        )
        note.maximumNumberOfLines = 0
        note.preferredMaxLayoutWidth = 300
        stack.addArrangedSubview(note)

        return stack
    }

    private func makeInstructionRow(number: Int, text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8

        // Number badge
        let badge = NSTextField(labelWithString: "\(number)")
        badge.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        badge.textColor = .white
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        badge.layer?.cornerRadius = 8
        badge.layer?.masksToBounds = true
        badge.widthAnchor.constraint(equalToConstant: 16).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let label = makeLabel(text, size: 11)
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 260

        row.addArrangedSubview(badge)
        row.addArrangedSubview(label)

        return row
    }

    // MARK: - Donate Button

    private func buildDonateButton() -> NSView {
        let button = NSButton(title: "☕ Buy me a coffee", target: self, action: #selector(donateTapped))
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        return button
    }

    @objc private func donateTapped() {
        if let url = URL(string: "https://buymeacoffee.com/hulryung") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Combine Bindings

    private func bindManager() {
        manager.$isMappingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.updateToggleUI(enabled: enabled)
            }
            .store(in: &cancellables)

        manager.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] loading in
                self?.toggleButton.isEnabled = !loading
                self?.toggleButton.title = loading ? String(localized: "button.processing") : (self?.manager.isMappingEnabled == true ? String(localized: "button.disable") : String(localized: "button.enable"))
            }
            .store(in: &cancellables)

        manager.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self else { return }
                if let message {
                    self.errorLabel.stringValue = message
                    self.errorLabel.isHidden = false
                    self.showErrorAlert(message)
                } else {
                    self.errorLabel.isHidden = true
                }
            }
            .store(in: &cancellables)

        manager.$sourceKeyInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] keyInfo in
                self?.keyLabel.stringValue = keyInfo.displayName
            }
            .store(in: &cancellables)

        // Update layer colors on appearance change (light/dark mode)
        view.publisher(for: \.effectiveAppearance)
            .sink { [weak self] _ in
                guard let self else { return }
                self.cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                self.updateToggleUI(enabled: self.manager.isMappingEnabled)
            }
            .store(in: &cancellables)
    }

    private func updateToggleUI(enabled: Bool) {
        // Status icon & label
        statusIcon.image = NSImage(
            systemSymbolName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill",
            accessibilityDescription: nil
        )
        statusIcon.contentTintColor = enabled ? .controlAccentColor : .systemGray

        statusLabel.stringValue = enabled ? String(localized: "status.enabled") : String(localized: "status.disabled")
        statusLabel.textColor = enabled ? .systemGreen : .systemRed

        // Toggle button
        toggleButton.title = enabled ? String(localized: "button.disable") : String(localized: "button.enable")
        toggleButton.layer?.backgroundColor = enabled ? NSColor.systemRed.cgColor : NSColor.controlAccentColor.cgColor

        // Change key button disabled while active
        changeKeyButton.isEnabled = !enabled
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "error.title")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "button.confirm"))
        if let window = view.window {
            alert.beginSheetModal(for: window)
        }
    }

    // MARK: - Actions

    @objc private func toggleTapped() {
        Task {
            if manager.isMappingEnabled {
                let success = await manager.disableMapping()
                if !success {
                    showErrorAlert(String(localized: "error.disable"))
                }
            } else {
                let success = await manager.enableMapping()
                if !success {
                    showErrorAlert(String(localized: "error.enable"))
                }
            }
        }
    }

    @objc private func changeKeyTapped() {
        showKeyCaptureSheet()
    }

    // MARK: - Key Capture Sheet

    private func showKeyCaptureSheet() {
        guard let window = view.window else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false

        let sheetVC = KeyCaptureSheetViewController(manager: manager, panel: panel)
        panel.contentViewController = sheetVC

        window.beginSheet(panel)
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func makeDivider() -> NSView {
        let divider = NSBox()
        divider.boxType = .separator
        return divider
    }
}

// MARK: - Key Capture Sheet ViewController

class KeyCaptureSheetViewController: NSViewController {

    private let manager: KeyMappingManager
    private let panel: NSPanel
    private var cancellable: AnyCancellable?
    private var pulseTimer: Timer?

    // UI
    private var iconView: NSImageView!
    private var mainLabel: NSTextField!
    private var subLabel: NSTextField!
    private var buttonsStack: NSStackView!

    init(manager: KeyMappingManager, panel: NSPanel) {
        self.manager = manager
        self.panel = panel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        pulseTimer?.invalidate()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        manager.startKeyCapture()

        // Start pulse animation
        startPulse()

        cancellable = manager.$capturedKeyInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] keyInfo in
                if let keyInfo {
                    self?.showCaptured(keyInfo)
                }
            }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        manager.stopKeyCapture()
        pulseTimer?.invalidate()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
        ])

        iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        stack.addArrangedSubview(iconView)

        mainLabel = NSTextField(labelWithString: String(localized: "keycapture.prompt"))
        mainLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        mainLabel.alignment = .center
        mainLabel.maximumNumberOfLines = 0
        stack.addArrangedSubview(mainLabel)

        subLabel = NSTextField(labelWithString: String(localized: "keycapture.hint"))
        subLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subLabel.textColor = .secondaryLabelColor
        subLabel.alignment = .center
        stack.addArrangedSubview(subLabel)

        buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 12

        let cancelButton = NSButton(title: String(localized: "button.cancel"), target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        buttonsStack.addArrangedSubview(cancelButton)

        stack.addArrangedSubview(buttonsStack)
    }

    private func showCaptured(_ keyInfo: KeyInfo) {
        pulseTimer?.invalidate()
        iconView.alphaValue = 1.0

        iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .systemGreen

        mainLabel.stringValue = keyInfo.displayName
        mainLabel.font = NSFont.systemFont(ofSize: 17, weight: .bold)

        subLabel.isHidden = true

        // Replace buttons
        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let retryButton = NSButton(title: String(localized: "button.retry"), target: self, action: #selector(retryTapped))
        retryButton.bezelStyle = .rounded

        let confirmButton = NSButton(title: String(localized: "button.confirm"), target: self, action: #selector(confirmTapped))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"

        buttonsStack.addArrangedSubview(retryButton)
        buttonsStack.addArrangedSubview(confirmButton)
    }

    private func startPulse() {
        var fadeIn = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.5
                self.iconView.animator().alphaValue = fadeIn ? 1.0 : 0.4
            }
            fadeIn.toggle()
        }
    }

    @objc private func cancelTapped() {
        manager.stopKeyCapture()
        view.window?.sheetParent?.endSheet(panel)
    }

    @objc private func retryTapped() {
        subLabel.isHidden = false
        mainLabel.stringValue = String(localized: "keycapture.prompt")
        mainLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor

        // Reset buttons
        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cancelButton = NSButton(title: String(localized: "button.cancel"), target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        buttonsStack.addArrangedSubview(cancelButton)

        startPulse()
        manager.startKeyCapture()
    }

    @objc private func confirmTapped() {
        if let captured = manager.capturedKeyInfo {
            manager.setSourceKey(captured)
        }
        manager.stopKeyCapture()
        view.window?.sheetParent?.endSheet(panel)
    }
}
