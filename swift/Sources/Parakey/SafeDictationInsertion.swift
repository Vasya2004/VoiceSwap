import AppKit
import ApplicationServices
import VoiceSwapCore

@MainActor
struct DictationInsertionTarget {
    let applicationPID: pid_t
    let field: AXUIElement
    let window: AXUIElement
    let valueAtStart: String
    let selectionAtStart: CFRange?

    static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let raw = attribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range) else { return nil }
        return range
    }
    static func capture() -> Self? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let raw = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let field = raw as! AXUIElement
        AXUIElementSetMessagingTimeout(field, 0.2)
        let role = attribute(field, kAXRoleAttribute) as? String
        let subrole = attribute(field, kAXSubroleAttribute) as? String
        guard role == kAXTextFieldRole || role == kAXTextAreaRole || role == kAXComboBoxRole,
              subrole != kAXSecureTextFieldSubrole,
              let value = attribute(field, kAXValueAttribute) as? String,
              let rawWindow = attribute(field, kAXWindowAttribute),
              CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else { return nil }
        return Self(applicationPID: app.processIdentifier, field: field,
                    window: rawWindow as! AXUIElement, valueAtStart: value,
                    selectionAtStart: selectedRange(field))
    }
    func matches(requireUnchangedContents: Bool = false) -> Bool {
        guard let current = Self.capture(), current.applicationPID == applicationPID,
              CFEqual(field, current.field), CFEqual(window, current.window) else { return false }
        if requireUnchangedContents {
            guard valueAtStart == current.valueAtStart else { return false }
            if let first = selectionAtStart, let second = current.selectionAtStart {
                return first.location == second.location && first.length == second.length
            }
            return selectionAtStart == nil && current.selectionAtStart == nil
        }
        return true
    }
    var value: String? { Self.attribute(field, kAXValueAttribute) as? String }
}

@MainActor
enum SafeDictationInsertion {
    static func perform(_ text: String, target: DictationInsertionTarget?, sendReturn: Bool,
                        delayMilliseconds: Int, isCurrent: () -> Bool) async -> InsertionOutcome {
        guard let target else { return .blocked }
        return await InsertionTransaction.perform(
            text: text, sendReturn: sendReturn, delayMilliseconds: delayMilliseconds,
            canStart: { target.matches(requireUnchangedContents: true) },
            isCurrent: isCurrent, targetMatches: { target.matches() },
            readText: { target.value }, dispatchOnce: { TextInserter.dispatchOnce(text) },
            postReturn: { KeyboardShortcutPoster.postReturn() }
        )
    }
}

@MainActor
final class DictationResultController: NSWindowController, NSWindowDelegate {
    private var text: String
    private let textView = NSTextView()
    init(text: String, uncertain: Bool, language: InterfaceLanguage) {
        self.text = text
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
                            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        super.init(window: panel)
        panel.title = localizedText("Результат диктовки", "Dictation result", language: language)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.level = .floating
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let message = uncertain
            ? localizedText("Вставка не подтверждена. Проверьте поле перед копированием, чтобы избежать дубля.", "Insertion was not confirmed. Check the field before copying to avoid a duplicate.", language: language)
            : localizedText("Поле изменилось или недоступно. Текст не вставлен.", "The target changed or is unavailable. Text was not inserted.", language: language)
        let label = NSTextField(wrappingLabelWithString: message)
        root.addArrangedSubview(label)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        root.addArrangedSubview(scroll)
        let copy = NSButton(title: localizedText("Копировать", "Copy", language: language), target: self, action: #selector(copyText))
        copy.bezelStyle = .rounded
        root.addArrangedSubview(copy)
        panel.contentView = root
        label.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32).isActive = true
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -32).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        panel.center()
    }
    required init?(coder: NSCoder) { nil }
    @objc private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    func windowWillClose(_ notification: Notification) { text = ""; textView.string = "" }
}
