//
//  WatchInputFormView.swift
//  ubo Watch App
//
//  Compact input form for watchOS: each field becomes a row in a Form.
//  Uses dictation/Scribble for text fields, Digital Crown for sliders, etc.
//  Submits via `provideInput`, dismisses via `cancelInput`.
//

import UboAppKit
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
                            do { try await viewModel.client.cancelInput(id: description.id) } catch { viewModel.report("cancelInput", error) }
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
        case .range:
            VStack(alignment: .leading) {
                Text(field.label)
                Slider(
                    value: Binding(
                        get: { Double(binding.wrappedValue) ?? 50 },
                        set: { binding.wrappedValue = String(Int($0)) }
                    ),
                    in: 0...100,
                    step: 1
                )
                Text("\(Int(Double(binding.wrappedValue) ?? 50))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            if field.type == .range {
                let defaultValue = field.defaultValue.flatMap(Double.init) ?? 50
                seeded[field.name] = String(Int(defaultValue))
            } else {
                seeded[field.name] = field.defaultValue ?? ""
            }
        }
        values = seeded
    }

    private func submit() async {
        let scalar = description.fields.first.flatMap { values[$0.name] } ?? ""
        UboLog.input.info("submitting input \(description.id) with scalar=\"\(scalar)\"")
        onClose()
        do { try await viewModel.client.provideInput(id: description.id, value: scalar) } catch { viewModel.report("provideInput", error) }
    }
}
