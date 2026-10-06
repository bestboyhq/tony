import ApplicationServices

/// What is around the cursor, where the focused app exposes it through Accessibility.
nonisolated enum Cursor {
    /// Up to three characters before the cursor: "" at the start of a field, nil when the app doesn't say.
    /// Read at key down, while the user speaks, so it costs nothing at key up. A hung app answers within
    /// the timeout or not at all.
    static func textBefore() -> String? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.1)
        var selection: CFTypeRef?
        var range = CFRange()
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection) == .success,
              let selection, CFGetTypeID(selection) == AXValueGetTypeID(),
              AXValueGetValue(selection as! AXValue, .cfRange, &range) else { return nil }
        if range.location <= 0 { return "" }
        var before = CFRange(location: max(0, range.location - 3), length: min(3, range.location))
        guard let parameter = AXValueCreate(.cfRange, &before) else { return nil }
        var text: CFTypeRef?
        if AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &text) == .success,
           let text = text as? String {
            return text
        }
        // Apps without the parameterized attribute: slice the value.
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let value = value as? String else { return nil }
        let utf16 = Array(value.utf16)
        guard before.location + before.length <= utf16.count else { return nil }
        return String(utf16CodeUnits: Array(utf16[before.location..<before.location + before.length]), count: before.length)
    }
}
