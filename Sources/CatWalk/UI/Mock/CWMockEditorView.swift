//
//  CWMockEditorView.swift
//  CatWalk
//

import SwiftUI

/// Create or edit a mock rule. Saving registers it (or replaces the rule with the same id).
struct CWMockEditorView: View {

    @State var draft: CWMockDraft
    @State private var errorMessage: String?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section("Request") {
                    TextField("Method (blank = any)", text: $draft.method).autocapitalization(.allCharacters)
                    Picker("Match", selection: $draft.kind) {
                        ForEach(CWMockDraft.Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Pattern", text: $draft.pattern).autocapitalization(.none).disableAutocorrection(true)
                }
                Section("Response") {
                    TextField("Status", text: $draft.status).keyboardType(.numberPad)
                    Stepper("Delay: \(draft.delay, specifier: "%.1f") s", value: $draft.delay, in: 0...30, step: 0.5)
                }
                Section("Headers (Name: value per line)") {
                    TextEditor(text: $draft.headersText)
                        .font(.system(.footnote, design: .monospaced))
                        .autocapitalization(.none)
                        .frame(minHeight: 70)
                }
                Section("Body") {
                    TextEditor(text: $draft.body)
                        .font(.system(.footnote, design: .monospaced))
                        .autocapitalization(.none)
                        .frame(minHeight: 140)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red) }
                }
            }
            .navigationTitle("Mock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        do {
            let existing = CatWalk.mocks.first { $0.id == draft.id }
            try CatWalk.mock(try draft.rule(isEnabled: existing?.isEnabled ?? true))
            presentationMode.wrappedValue.dismiss()
        } catch let error as CWMockDraft.ValidationError {
            errorMessage = Self.message(for: error)
        } catch CWConfigurationError.invalidMockPattern {
            errorMessage = "The regular expression is not valid."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func message(for error: CWMockDraft.ValidationError) -> String {
        switch error {
        case .emptyPattern: "Enter a URL or pattern to match."
        case .invalidStatus: "Status must be a number from 100 to 599."
        case let .invalidHeader(line): "Header line is not “Name: value”: \(line)"
        }
    }
}
