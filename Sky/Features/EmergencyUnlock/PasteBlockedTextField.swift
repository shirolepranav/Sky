// PasteBlockedTextField.swift
// UIViewRepresentable wrapping a UITextView subclass that blocks all paste,
// copy, cut, and dictation via canPerformAction overrides, and rejects any
// replacement string longer than 5 characters or containing a newline in the
// UITextViewDelegate — catching paste-bypass attempts and enforcing single-paragraph
// input. Used in S-EMG-02.
// Sky_Technical_Spec.md §9; Sky_App_Workflow.md S-EMG-02; Roadmap Phase 13.

import SwiftUI

#if canImport(UIKit)
import UIKit

struct PasteBlockedTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int
    /// VoiceOver label for the field. Defaults to the emergency-unlock wording;
    /// Pause-Sky (S-SET-03) overrides it.
    var accessibilityLabelText: String = "Reason for emergency unlock. Paste is disabled. Type at least 20 characters."
    /// Called when a paste, >5-char insertion, newline, or max-length hit is rejected.
    var onRejectedInsertion: (() -> Void)? = nil

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> NoPasteTextView {
        let tv = NoPasteTextView()
        tv.delegate = context.coordinator
        tv.font = UIFont(name: "Nunito-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
        tv.textColor = UIColor(SkyColor.ink)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.autocapitalizationType = .sentences
        tv.autocorrectionType = .yes
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.returnKeyType = .done // shown but delegate rejects newlines
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        tv.textContainer.lineFragmentPadding = 0

        // Placeholder logic via attributed text when empty
        tv.text = text.isEmpty ? placeholder : text
        tv.textColor = text.isEmpty
            ? UIColor(SkyColor.inkMuted)
            : UIColor(SkyColor.ink)

        tv.accessibilityLabel = accessibilityLabelText
        return tv
    }

    func updateUIView(_ uiView: NoPasteTextView, context: Context) {
        guard uiView.text != text else { return }
        // Only sync externally-changed text (rare); don't fight active editing.
        if !uiView.isFirstResponder {
            uiView.text = text
            uiView.textColor = UIColor(SkyColor.ink)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: Coordinator / delegate

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PasteBlockedTextField

        init(parent: PasteBlockedTextField) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Clear placeholder on first focus
            if textView.textColor == UIColor(SkyColor.inkMuted) {
                textView.text = ""
                textView.textColor = UIColor(SkyColor.ink)
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor(SkyColor.inkMuted)
            }
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Reject newlines — this is a single-paragraph field
            if text.contains("\n") {
                parent.onRejectedInsertion?()
                return false
            }
            // Reject strings > 5 chars — catches paste-bypass workarounds
            // (legitimate autocomplete completions are usually ≤ 5 chars)
            if text.count > 5 {
                parent.onRejectedInsertion?()
                return false
            }
            // Enforce maxLength
            let current = textView.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let proposed = current.replacingCharacters(in: swiftRange, with: text)
            if proposed.count > parent.maxLength {
                parent.onRejectedInsertion?()
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// MARK: - NoPasteTextView

/// UITextView subclass that hides paste, copy, cut, select, and dictation from
/// the context menu and any other action-dispatch path.
final class NoPasteTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let blocked: [Selector] = [
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.copy(_:)),
            #selector(UIResponderStandardEditActions.cut(_:)),
            #selector(UIResponderStandardEditActions.select(_:)),
            #selector(UIResponderStandardEditActions.selectAll(_:)),
        ]
        if blocked.contains(action) { return false }
        let name = String(describing: action).lowercased()
        if name.contains("paste") ||
           name.contains("dictation") ||
           name.contains("translate") ||
           name.contains("share") {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
#endif
