//
//  InputFormView.swift
//  ubo-swift-app
//
//  Native iOS rendering of `WebUIInputDescription`. Replaces the "go to
//  the Web UI" redirect with on-device SwiftUI form controls. Each field
//  type maps to its native control; on submit the form dispatches
//  `InputProvideAction`, on cancel it dispatches `InputCancelAction`.
//

import SwiftUI
import UboSwift
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct InputFormView: View {
    let description: WebUIInputDescription
    /// Called by Cancel/Submit so the parent can immediately stop
    /// presenting this sheet, even before the server's state update
    /// for the resolved demand has propagated back over gRPC.
    let onClose: () -> Void

    @Environment(DeviceViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]
    @State private var validationErrors: [String: String] = [:]
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if let prompt = description.prompt, !prompt.isEmpty {
                    Section {
                        Text(prompt)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(description.fields) { field in
                    Section {
                        InputFieldEditor(
                            field: field,
                            value: binding(for: field),
                            error: validationErrors[field.name]
                        )
                    } header: {
                        if !field.label.isEmpty {
                            Text(field.label)
                        }
                    } footer: {
                        if let hint = field.description, !hint.isEmpty {
                            Text(hint)
                        }
                    }
                }
            }
            .navigationTitle(description.title ?? "Input")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        UboLog.input.info("user cancelled input \(description.id)")
                        onClose()
                        Task {
                            try? await viewModel.client.cancelInput(id: description.id)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting)
                }
            }
            .onAppear { seedDefaults() }
        }
    }

    private func binding(for field: InputFieldDescription) -> Binding<String> {
        Binding(
            get: { values[field.name] ?? "" },
            set: { values[field.name] = $0 }
        )
    }

    private func seedDefaults() {
        guard values.isEmpty else { return }
        var seeded: [String: String] = [:]
        for field in description.fields {
            seeded[field.name] = field.defaultValue ?? ""
        }
        values = seeded
    }

    private func validate() -> Bool {
        var errors: [String: String] = [:]
        for field in description.fields {
            let value = values[field.name] ?? ""
            if field.required && value.isEmpty {
                errors[field.name] = "Required"
                continue
            }
            if let pattern = field.pattern, !pattern.isEmpty, !value.isEmpty {
                if (try? NSRegularExpression(pattern: pattern))?
                    .firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil {
                    errors[field.name] = "Invalid format"
                }
            }
        }
        validationErrors = errors
        return errors.isEmpty
    }

    private func submit() async {
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        // Web UI's contract: `value` carries the primary scalar (first field's
        // value if there's only one), and structured `result.data` carries
        // the full map. The Python core inspects `value` first; for now we
        // pass the first field's value as the scalar — multi-field forms
        // rely on the Web UI's encoding, which we don't replicate yet.
        let scalar = description.fields.first.flatMap { values[$0.name] } ?? ""
        UboLog.input.info("submitting input \(description.id) with scalar=\"\(scalar)\"")
        onClose()
        try? await viewModel.client.provideInput(id: description.id, value: scalar)
    }
}

private struct InputFieldEditor: View {
    let field: InputFieldDescription
    @Binding var value: String
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch field.type {
            case .text:
                TextField(field.label, text: $value)
                    #if os(iOS)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()
                    #endif
            case .password:
                SecureField(field.label, text: $value)
            case .number:
                TextField(field.label, text: $value)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            case .long:
                TextField(field.label, text: $value, axis: .vertical)
                    .lineLimit(4...8)
            case .checkbox:
                Toggle(field.label, isOn: Binding(
                    get: { value == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
            case .color:
                ColorPicker(field.label, selection: Binding(
                    get: { Color(hex: value) ?? .accentColor },
                    set: { newColor in
                        if let hex = newColor.toHexString() {
                            value = hex
                        }
                    }
                ))
            case .select:
                Picker(field.label, selection: $value) {
                    ForEach(field.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            case .file:
                FilePickerButton(field: field, value: $value)
            case .date:
                DatePicker(
                    field.label,
                    selection: Binding(
                        get: { isoDateFormatter.date(from: value) ?? Date() },
                        set: { value = isoDateFormatter.string(from: $0) }
                    ),
                    displayedComponents: .date
                )
            case .time:
                DatePicker(
                    field.label,
                    selection: Binding(
                        get: { isoTimeFormatter.date(from: value) ?? Date() },
                        set: { value = isoTimeFormatter.string(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct FilePickerButton: View {
    let field: InputFieldDescription
    @Binding var value: String

    #if os(iOS)
    @State private var isPickerPresented = false
    #endif

    var body: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isPickerPresented = true
            } label: {
                Label(value.isEmpty ? "Choose file" : value, systemImage: "paperclip")
            }
            if !value.isEmpty {
                Text("Selected: \(value)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // For now we only carry the file path/name. Chunked
                    // upload via InputResult.files is a TODO that mirrors
                    // the Web UI's 512 KB / 3-retry contract.
                    value = url.lastPathComponent
                }
            case .failure:
                break
            }
        }
        #else
        TextField(field.label, text: $value)
        #endif
    }
}

private let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let isoTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

private extension Color {
    func toHexString() -> String? {
        #if os(iOS)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(
            format: "#%02x%02x%02x",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded())
        )
        #else
        return nil
        #endif
    }
}
