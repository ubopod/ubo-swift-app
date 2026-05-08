//
//  WatchInputFormView.swift
//  ubo Watch App
//
//  Compact input form for watchOS: each field becomes a row in a Form.
//  Uses dictation/Scribble for text fields, Digital Crown for sliders, etc.
//  Submits via `provideInput`, dismisses via `cancelInput`.
//

import SwiftUI
import UboSwift

struct WatchInputFormView: View {
    let description: WebUIInputDescription
    /// Called by Cancel/Submit so the parent can immediately stop
    /// presenting this sheet without waiting for the server's state
    /// update to propagate back.
    let onClose: () -> Void

    @Environment(DeviceViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                if let prompt = description.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(description.fields) { field in
                    fieldEditor(for: field)
                }

                Section {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel", role: .cancel) {
                        UboLog.input.info("user cancelled input \(description.id)")
                        onClose()
                        Task {
                            try? await viewModel.client.cancelInput(id: description.id)
                        }
                    }
                }
            }
            .navigationTitle(description.title ?? "Input")
            .onAppear { seedDefaults() }
        }
    }

    @ViewBuilder
    private func fieldEditor(for field: InputFieldDescription) -> some View {
        let binding = Binding(
            get: { values[field.name] ?? "" },
            set: { values[field.name] = $0 }
        )
        switch field.type {
        case .text, .long, .number:
            TextField(field.label, text: binding)
        case .password:
            SecureField(field.label, text: binding)
        case .checkbox:
            Toggle(field.label, isOn: Binding(
                get: { binding.wrappedValue == "true" },
                set: { binding.wrappedValue = $0 ? "true" : "false" }
            ))
        case .select:
            Picker(field.label, selection: binding) {
                ForEach(field.options, id: \.self) { Text($0).tag($0) }
            }
        case .color, .file, .date, .time:
            // Watch has no first-class control for these; fall back to text.
            TextField(field.label, text: binding)
        }
    }

    private func seedDefaults() {
        guard values.isEmpty else { return }
        var seeded: [String: String] = [:]
        for field in description.fields {
            seeded[field.name] = field.defaultValue ?? ""
        }
        values = seeded
    }

    private func submit() async {
        let scalar = description.fields.first.flatMap { values[$0.name] } ?? ""
        UboLog.input.info("submitting input \(description.id) with scalar=\"\(scalar)\"")
        onClose()
        try? await viewModel.client.provideInput(id: description.id, value: scalar)
    }
}
