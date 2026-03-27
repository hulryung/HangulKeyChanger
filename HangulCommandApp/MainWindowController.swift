import Cocoa
import Combine

// MARK: - MainWindowController

class MainWindowController: NSWindowController, NSWindowDelegate {

    init(viewController: MainViewController) {
        let window = NSWindow(contentViewController: viewController)
        window.title = "Hangul Key Changer"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 380, height: 10))
        window.center()
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
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
    private let lang = LanguageManager.shared
    private var cancellables = Set<AnyCancellable>()

    // UI elements that need updating
    private var subtitleLabel: NSTextField!
    private var keyTitleLabel: NSTextField!
    private var keyLabel: NSTextField!
    private var changeKeyButton: NSButton!
    private var statusIcon: NSImageView!
    private var statusTitleLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var toggleButton: NSButton!
    private var errorLabel: NSTextField!
    private var cardView: NSStackView!
    private var instructionsTitleLabel: NSTextField!
    private var instructionStep1Label: NSTextField!
    private var instructionStep2Label: NSTextField!
    private var instructionNoteLabel: NSTextField!
    private var langSegment: NSSegmentedControl!
    private var loveLabel: NSTextField!

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

    // MARK: - Localization Helper

    private func L(_ key: String) -> String {
        lang.localized(key)
    }

    private func updateAllStrings() {
        subtitleLabel.stringValue = L("app.subtitle")
        keyTitleLabel.stringValue = L("key.switch")
        changeKeyButton.title = L("button.change")
        statusTitleLabel.stringValue = L("status")
        instructionsTitleLabel.stringValue = L("instructions.title")
        instructionStep1Label.stringValue = L("instructions.step1")
        instructionStep2Label.stringValue = L("instructions.step2")
        instructionNoteLabel.stringValue = L("instructions.note")

        // Update love message
        let loveText = NSMutableAttributedString()
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let heartAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.systemRed,
        ]
        let loveMsg = lang.language == "ko" ? "한글을 사랑합니다" : "We love Hangul"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        loveText.append(NSAttributedString(string: loveMsg + " ", attributes: textAttrs))
        loveText.append(NSAttributedString(string: "♥", attributes: heartAttrs))
        loveText.append(NSAttributedString(string: "  v\(version)", attributes: textAttrs))
        loveLabel.attributedStringValue = loveText

        // Re-apply state-dependent labels
        updateToggleUI(enabled: manager.isMappingEnabled)

        // Resize window to fit new content
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        if let window = view.window {
            let contentSize = window.contentView?.fittingSize ?? view.fittingSize
            var frame = window.frame
            let newHeight = contentSize.height + (frame.height - window.contentLayoutRect.height)
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            window.setFrame(frame, display: true)
        }
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
            mainStack.widthAnchor.constraint(equalToConstant: 380),
        ])

        // 1. Header
        let header = buildHeader()
        mainStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true

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

        // 6. Divider + Footer (version + links)
        mainStack.addArrangedSubview(makeDivider())
        let footer = buildFooter()
        mainStack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
    }

    // MARK: - Header

    private func buildHeader() -> NSView {
        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 4

        // Top row: icon + title + lang toggle
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = makeLabel("Hangul Key Changer", size: 17, weight: .bold)

        // Language toggle
        langSegment = NSSegmentedControl(labels: ["KO", "EN"], trackingMode: .selectOne, target: self, action: #selector(languageChanged))
        langSegment.segmentStyle = .rounded
        langSegment.controlSize = .small
        langSegment.selectedSegment = lang.language == "ko" ? 0 : 1
        langSegment.setContentHuggingPriority(.required, for: .horizontal)

        topRow.addArrangedSubview(icon)
        topRow.addArrangedSubview(title)
        topRow.addArrangedSubview(langSegment)

        // Subtitle below, full width
        subtitleLabel = makeLabel(L("app.subtitle"), size: 12, color: .secondaryLabelColor)
        subtitleLabel.maximumNumberOfLines = 1

        outerStack.addArrangedSubview(topRow)
        outerStack.addArrangedSubview(subtitleLabel)

        return outerStack
    }

    @objc private func languageChanged() {
        let selected = langSegment.selectedSegment == 0 ? "ko" : "en"
        lang.setLanguage(selected)
        updateAllStrings()
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

        keyTitleLabel = makeLabel(L("key.switch"), size: 12, color: .secondaryLabelColor)
        keyTitleLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        keyTitleLabel.setContentHuggingPriority(.required, for: .horizontal)

        keyLabel = makeLabel(manager.sourceKeyInfo.displayName, size: 13, weight: .medium)
        keyLabel.alignment = .right
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.maximumNumberOfLines = 1
        keyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        changeKeyButton = NSButton(title: L("button.change"), target: self, action: #selector(changeKeyTapped))
        changeKeyButton.bezelStyle = .rounded
        changeKeyButton.controlSize = .small
        changeKeyButton.setContentHuggingPriority(.required, for: .horizontal)

        keyRow.addArrangedSubview(keyIcon)
        keyRow.addArrangedSubview(keyTitleLabel)
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
        statusRow.spacing = 8

        statusIcon = NSImageView()
        statusIcon.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        statusIcon.contentTintColor = .systemGray
        statusIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        statusIcon.setContentHuggingPriority(.required, for: .horizontal)

        statusTitleLabel = makeLabel(L("status"), size: 12, color: .secondaryLabelColor)
        statusTitleLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        statusTitleLabel.setContentHuggingPriority(.required, for: .horizontal)

        statusLabel = makeLabel(L("status.disabled"), size: 13, weight: .medium)
        statusLabel.textColor = .systemRed
        statusLabel.alignment = .right

        statusRow.addArrangedSubview(statusIcon)
        statusRow.addArrangedSubview(statusTitleLabel)
        statusRow.addArrangedSubview(statusLabel)

        card.addArrangedSubview(statusRow)
        statusRow.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -28).isActive = true

        // Toggle button
        toggleButton = NSButton(title: L("button.enable"), target: self, action: #selector(toggleTapped))
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

        instructionsTitleLabel = makeLabel(L("instructions.title"), size: 12, weight: .semibold)
        stack.addArrangedSubview(instructionsTitleLabel)

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6

        instructionStep1Label = makeLabel(L("instructions.step1"), size: 11)
        instructionStep1Label.maximumNumberOfLines = 0
        instructionStep1Label.preferredMaxLayoutWidth = 260
        rows.addArrangedSubview(makeInstructionRow(number: 1, label: instructionStep1Label))

        instructionStep2Label = makeLabel(L("instructions.step2"), size: 11)
        instructionStep2Label.maximumNumberOfLines = 0
        instructionStep2Label.preferredMaxLayoutWidth = 260
        rows.addArrangedSubview(makeInstructionRow(number: 2, label: instructionStep2Label))

        stack.addArrangedSubview(rows)

        instructionNoteLabel = makeLabel(L("instructions.note"), size: 10, color: .secondaryLabelColor)
        instructionNoteLabel.maximumNumberOfLines = 0
        instructionNoteLabel.preferredMaxLayoutWidth = 300
        stack.addArrangedSubview(instructionNoteLabel)

        return stack
    }

    private func makeInstructionRow(number: Int, label: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        // Number badge
        let badge = BadgeView(number: number)
        badge.widthAnchor.constraint(equalToConstant: 16).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        row.addArrangedSubview(badge)
        row.addArrangedSubview(label)

        return row
    }

    // MARK: - Footer

    private func buildFooter() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 8

        stack.addArrangedSubview(makeLinkButton(symbolName: "globe.asia.australia", url: "https://hkc.hulryung.com", tooltip: "Website"))
        stack.addArrangedSubview(makeLinkButton(image: Self.githubIcon(), url: "https://github.com/hulryung/HangulKeyChanger", tooltip: "GitHub"))
        stack.addArrangedSubview(makeLinkButton(image: Self.xIcon(), url: "https://x.com/hulryung", tooltip: "X"))

        // Flexible spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        stack.addArrangedSubview(spacer)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let loveText = NSMutableAttributedString()
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let heartAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.systemRed,
        ]
        let loveMsg = lang.language == "ko" ? "한글을 사랑합니다" : "We love Hangul"
        loveText.append(NSAttributedString(string: loveMsg + " ", attributes: textAttrs))
        loveText.append(NSAttributedString(string: "♥", attributes: heartAttrs))
        loveText.append(NSAttributedString(string: "  v\(version)", attributes: textAttrs))

        let loveLabel = NSTextField(labelWithAttributedString: loveText)
        loveLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.loveLabel = loveLabel

        stack.addArrangedSubview(loveLabel)

        return stack
    }

    private func makeLinkButton(symbolName: String? = nil, image: NSImage? = nil, url: String, tooltip: String) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.isBordered = false
        button.toolTip = tooltip
        button.target = self
        button.action = #selector(linkButtonTapped(_:))
        button.identifier = NSUserInterfaceItemIdentifier(url)

        if let symbolName {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
            button.contentTintColor = .secondaryLabelColor
        } else if let image {
            button.image = image
        }

        button.imageScaling = .scaleProportionallyDown
        button.widthAnchor.constraint(equalToConstant: 20).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)

        return button
    }

    /// GitHub mark (official SVG path scaled to 16x16, flipped for AppKit)
    private static func githubIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        return NSImage(size: size, flipped: true) { rect in
            NSColor.secondaryLabelColor.setFill()
            let scale: CGFloat = 16.0 / 98.0
            let path = NSBezierPath()
            // GitHub official Invertocat path (viewBox 0 0 98 96)
            let cgPath = CGMutablePath()
            cgPath.move(to: CGPoint(x: 48.854, y: 0))
            cgPath.addCurve(to: CGPoint(x: 0, y: 49.217), control1: CGPoint(x: 21.839, y: 0), control2: CGPoint(x: 0, y: 22.000))
            cgPath.addCurve(to: CGPoint(x: 33.417, y: 95.528), control1: CGPoint(x: 0, y: 71.026), control2: CGPoint(x: 13.114, y: 89.836))
            cgPath.addCurve(to: CGPoint(x: 36.751, y: 91.929), control1: CGPoint(x: 35.937, y: 95.996), control2: CGPoint(x: 36.751, y: 94.592))
            cgPath.addLine(to: CGPoint(x: 36.751, y: 84.349))
            cgPath.addCurve(to: CGPoint(x: 6.025, y: 73.451), control1: CGPoint(x: 23.109, y: 87.009), control2: CGPoint(x: 6.025, y: 73.451))
            cgPath.addCurve(to: CGPoint(x: 1.244, y: 61.078), control1: CGPoint(x: 4.563, y: 68.074), control2: CGPoint(x: 1.244, y: 61.078))
            cgPath.addCurve(to: CGPoint(x: 10.006, y: 59.903), control1: CGPoint(x: 1.244, y: 61.078), control2: CGPoint(x: 6.556, y: 57.852))
            cgPath.addCurve(to: CGPoint(x: 16.320, y: 72.276), control1: CGPoint(x: 13.456, y: 61.954), control2: CGPoint(x: 16.320, y: 72.276))
            cgPath.addCurve(to: CGPoint(x: 39.495, y: 75.820), control1: CGPoint(x: 21.830, y: 82.869), control2: CGPoint(x: 34.516, y: 79.420))
            cgPath.addCurve(to: CGPoint(x: 41.409, y: 68.664), control1: CGPoint(x: 39.964, y: 72.922), control2: CGPoint(x: 40.598, y: 70.534))
            cgPath.addCurve(to: CGPoint(x: 18.355, y: 45.617), control1: CGPoint(x: 28.298, y: 67.137), control2: CGPoint(x: 18.355, y: 63.150))
            cgPath.addCurve(to: CGPoint(x: 24.668, y: 31.886), control1: CGPoint(x: 18.355, y: 39.651), control2: CGPoint(x: 20.627, y: 35.501))
            cgPath.addCurve(to: CGPoint(x: 25.199, y: 17.567), control1: CGPoint(x: 23.737, y: 29.562), control2: CGPoint(x: 23.988, y: 23.533))
            cgPath.addCurve(to: CGPoint(x: 36.220, y: 21.767), control1: CGPoint(x: 25.199, y: 17.567), control2: CGPoint(x: 29.211, y: 18.636))
            cgPath.addCurve(to: CGPoint(x: 48.854, y: 20.003), control1: CGPoint(x: 39.670, y: 20.828), control2: CGPoint(x: 44.223, y: 20.003))
            cgPath.addCurve(to: CGPoint(x: 61.489, y: 21.767), control1: CGPoint(x: 53.486, y: 20.003), control2: CGPoint(x: 58.039, y: 20.828))
            cgPath.addCurve(to: CGPoint(x: 72.510, y: 17.567), control1: CGPoint(x: 68.498, y: 18.636), control2: CGPoint(x: 72.510, y: 17.567))
            cgPath.addCurve(to: CGPoint(x: 73.041, y: 31.886), control1: CGPoint(x: 73.721, y: 23.533), control2: CGPoint(x: 73.972, y: 29.562))
            cgPath.addCurve(to: CGPoint(x: 79.354, y: 45.617), control1: CGPoint(x: 77.082, y: 35.501), control2: CGPoint(x: 79.354, y: 39.651))
            cgPath.addCurve(to: CGPoint(x: 56.300, y: 68.664), control1: CGPoint(x: 79.354, y: 63.150), control2: CGPoint(x: 69.411, y: 67.137))
            cgPath.addCurve(to: CGPoint(x: 58.503, y: 77.530), control1: CGPoint(x: 57.642, y: 70.876), control2: CGPoint(x: 58.503, y: 73.451))
            cgPath.addLine(to: CGPoint(x: 58.503, y: 91.929))
            cgPath.addCurve(to: CGPoint(x: 61.837, y: 95.528), control1: CGPoint(x: 58.503, y: 94.592), control2: CGPoint(x: 59.787, y: 95.996))
            cgPath.addCurve(to: CGPoint(x: 97.709, y: 49.217), control1: CGPoint(x: 84.595, y: 89.836), control2: CGPoint(x: 97.709, y: 71.026))
            cgPath.addCurve(to: CGPoint(x: 48.854, y: 0), control1: CGPoint(x: 97.709, y: 22.000), control2: CGPoint(x: 75.870, y: 0))
            cgPath.closeSubpath()

            let transform = CGAffineTransform(scaleX: scale, y: scale)
            if let scaled = cgPath.copy(using: [transform]) {
                path.append(NSBezierPath(cgPath: scaled))
            }
            path.fill()
            return true
        }
    }

    /// X (Twitter) official logo (viewBox 0 0 1200 1227, scaled to 16x16)
    private static func xIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        return NSImage(size: size, flipped: true) { rect in
            NSColor.secondaryLabelColor.setFill()
            let scale: CGFloat = 14.0 / 1227.0
            let offset: CGFloat = 1.0 // center in 16x16
            let cgPath = CGMutablePath()
            // Outer X shape
            cgPath.move(to: CGPoint(x: 714.163, y: 519.284))
            cgPath.addLine(to: CGPoint(x: 1160.89, y: 0))
            cgPath.addLine(to: CGPoint(x: 1055.03, y: 0))
            cgPath.addLine(to: CGPoint(x: 671.869, y: 450.887))
            cgPath.addLine(to: CGPoint(x: 357.328, y: 0))
            cgPath.addLine(to: CGPoint(x: 0, y: 0))
            cgPath.addLine(to: CGPoint(x: 468.492, y: 681.821))
            cgPath.addLine(to: CGPoint(x: 0, y: 1226.37))
            cgPath.addLine(to: CGPoint(x: 105.866, y: 1226.37))
            cgPath.addLine(to: CGPoint(x: 510.788, y: 750.218))
            cgPath.addLine(to: CGPoint(x: 842.672, y: 1226.37))
            cgPath.addLine(to: CGPoint(x: 1200, y: 1226.37))
            cgPath.closeSubpath()
            // Inner cutout
            cgPath.move(to: CGPoint(x: 167.0, y: 79.6348))
            cgPath.addLine(to: CGPoint(x: 306.0, y: 79.6348))
            cgPath.addLine(to: CGPoint(x: 1033.0, y: 1146.74))
            cgPath.addLine(to: CGPoint(x: 894.0, y: 1146.74))
            cgPath.closeSubpath()

            var transform = CGAffineTransform(scaleX: scale, y: scale)
            transform = transform.translatedBy(x: offset / scale, y: offset / scale)
            if let scaled = cgPath.copy(using: &transform) {
                let nsPath = NSBezierPath(cgPath: scaled)
                nsPath.windingRule = .evenOdd
                nsPath.fill()
            }
            return true
        }
    }

    @objc private func linkButtonTapped(_ sender: NSButton) {
        if let urlString = sender.identifier?.rawValue, let url = URL(string: urlString) {
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
                guard let self else { return }
                self.toggleButton.isEnabled = !loading
                self.toggleButton.title = loading ? L("button.processing") : (manager.isMappingEnabled ? L("button.disable") : L("button.enable"))
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

        statusLabel.stringValue = enabled ? L("status.enabled") : L("status.disabled")
        statusLabel.textColor = enabled ? .systemGreen : .systemRed

        // Toggle button
        toggleButton.title = enabled ? L("button.disable") : L("button.enable")
        toggleButton.layer?.backgroundColor = enabled ? NSColor.systemRed.cgColor : NSColor.controlAccentColor.cgColor

        // Change key button disabled while active
        changeKeyButton.isEnabled = !enabled
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L("error.title")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button.confirm"))
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
                    showErrorAlert(L("error.disable"))
                }
            } else {
                let success = await manager.enableMapping()
                if !success {
                    showErrorAlert(L("error.enable"))
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
    private let lang = LanguageManager.shared
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

    private func L(_ key: String) -> String {
        lang.localized(key)
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

        mainLabel = NSTextField(labelWithString: L("keycapture.prompt"))
        mainLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        mainLabel.alignment = .center
        mainLabel.maximumNumberOfLines = 0
        stack.addArrangedSubview(mainLabel)

        subLabel = NSTextField(labelWithString: L("keycapture.hint"))
        subLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subLabel.textColor = .secondaryLabelColor
        subLabel.alignment = .center
        stack.addArrangedSubview(subLabel)

        buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 12

        let cancelButton = NSButton(title: L("button.cancel"), target: self, action: #selector(cancelTapped))
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

        let retryButton = NSButton(title: L("button.retry"), target: self, action: #selector(retryTapped))
        retryButton.bezelStyle = .rounded

        let confirmButton = NSButton(title: L("button.confirm"), target: self, action: #selector(confirmTapped))
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
        mainLabel.stringValue = L("keycapture.prompt")
        mainLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor

        // Reset buttons
        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cancelButton = NSButton(title: L("button.cancel"), target: self, action: #selector(cancelTapped))
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

// MARK: - BadgeView

private class BadgeView: NSView {
    private let number: Int

    init(number: Int) {
        self.number = number
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        path.fill()

        let text = "\(number)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
}
