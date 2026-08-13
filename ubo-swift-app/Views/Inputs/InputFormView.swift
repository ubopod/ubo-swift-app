//
//  InputFormView.swift
//  ubo-swift-app
//
//  Native iOS rendering of `WebUIInputDescription`. Replaces the "go to
//  the Web UI" redirect with on-device SwiftUI form controls. Each field
//  type maps to its native control; on submit the form dispatches
//  `InputProvideAction`, on cancel it dispatches `InputCancelAction`.
//
//  `prompt` is the primary heading and `title` an optional elaboration
//  shown below it — matching the Web UI's `Inputs` component (`prompt` ->
//  `DialogTitle`, `title` -> linkified subtitle), not the field names'
//  intuitive-looking-but-wrong opposite reading. Getting this backwards
//  previously sent a several-hundred-character OAuth URL straight into
//  `.navigationTitle`, where it silently truncated to "Open https://...".
//

import UboAppKit
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
    /// FILE fields picked but not yet uploaded, keyed by field name. Sent in
    /// the background after submit — see `submit()`.
    @State private var pendingUploads: [String: PendingUpload] = [:]

    var body: some View {
        NavigationStack {
            Form {
                if let subtitle = description.title, !subtitle.isEmpty {
                    Section {
                        LinkifiedText(text: subtitle)
                    }
                }

                ForEach(description.fields) { field in
                    Section {
                        InputFieldEditor(
                            field: field,
                            value: binding(for: field),
                            error: validationErrors[field.name],
                            onFilePicked: { pendingUploads[field.name] = $0 }
                        )
                    } header: {
                        if !field.label.isEmpty {
                            Text(field.label)
                        }
                    } footer: {
                        if let hint = field.description, !hint.isEmpty {
                            LinkifiedText(text: hint, font: .caption)
                        }
                    }
                }
            }
            .navigationTitle(description.prompt ?? "Input")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        UboLog.input.info("user cancelled input \(description.id)")
                        onClose()
                        Task {
                            do { try await viewModel.client.cancelInput(id: description.id) } catch { viewModel.report("cancelInput", error) }
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
            if field.type == .range {
                let defaultValue = field.defaultValue.flatMap(Double.init) ?? 50
                seeded[field.name] = String(Int(defaultValue))
            } else {
                seeded[field.name] = field.defaultValue ?? ""
            }
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
        // every field's name -> value. Server-side handlers for multi-field
        // forms read `result.data`, not `value`.
        var data = values
        // FILE fields: the server never sees the bytes through `data` — it
        // reads `{field}_upload_id`/`{field}_name` and waits for a matching
        // chunked upload (started below) to complete. Mirrors the Web UI's
        // `inputs.tsx`.
        for (fieldName, pending) in pendingUploads {
            data["\(fieldName)_upload_id"] = pending.uploadId
            data["\(fieldName)_name"] = pending.filename
        }
        let scalar = description.fields.first.flatMap { data[$0.name] } ?? ""
        UboLog.input.info("submitting input \(description.id) with scalar=\"\(scalar)\"")
        onClose()
        do {
            try await viewModel.client.provideInput(id: description.id, value: scalar, data: data)
        } catch {
            viewModel.report("provideInput", error)
            return
        }
        // Uploads run after the form has been accepted, same as the Web UI —
        // the server's await_completed_upload has its own timeout to cover
        // this arriving after the InputProvideAction that references it.
        for pending in pendingUploads.values {
            Task {
                do {
                    try await viewModel.client.uploadFile(id: pending.uploadId, filename: pending.filename, data: pending.data)
                } catch { viewModel.report("uploadFile", error) }
            }
        }
    }
}

private struct InputFieldEditor: View {
    let field: InputFieldDescription
    @Binding var value: String
    let error: String?
    let onFilePicked: (PendingUpload) -> Void

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
                #if os(tvOS)
                TextField(field.label, text: $value)
                #else
                ColorPicker(field.label, selection: Binding(
                    get: { Color(hex: value) ?? .accentColor },
                    set: { newColor in
                        if let hex = newColor.toHexString() {
                            value = hex
                        }
                    }
                ))
                #endif
            case .select:
                Picker(field.label, selection: $value) {
                    ForEach(field.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            case .range:
                #if os(tvOS)
                TextField(field.label, text: $value)
                #else
                Slider(
                    value: Binding(
                        get: { Double(value) ?? 50 },
                        set: { value = String(Int($0)) }
                    ),
                    in: 0...100,
                    step: 1
                ) {
                    Text(field.label)
                }
                Text("\(Int(Double(value) ?? 50))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            case .file:
                FilePickerButton(field: field, value: $value, onFilePicked: onFilePicked)
            case .date:
                #if os(tvOS)
                TextField(field.label, text: $value)
                #else
                DatePicker(
                    field.label,
                    selection: Binding(
                        get: { isoDateFormatter.date(from: value) ?? Date() },
                        set: { value = isoDateFormatter.string(from: $0) }
                    ),
                    displayedComponents: .date
                )
                #endif
            case .time:
                #if os(tvOS)
                TextField(field.label, text: $value)
                #else
                DatePicker(
                    field.label,
                    selection: Binding(
                        get: { isoTimeFormatter.date(from: value) ?? Date() },
                        set: { value = isoTimeFormatter.string(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                #endif
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// A FILE field picked and read into memory, ready to hand to
/// `UboClient.uploadFile`. `uploadId` is generated on pick (not on submit)
/// so it's stable if the user re-opens the picker before submitting.
struct PendingUpload {
    let uploadId: String
    let filename: String
    let data: Data
}

private struct FilePickerButton: View {
    let field: InputFieldDescription
    @Binding var value: String
    let onFilePicked: (PendingUpload) -> Void

    #if os(iOS)
    @State private var isPickerPresented = false
    @State private var readError: String?
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
            if let readError {
                Text(readError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                readError = nil
                Task {
                    let filename = url.lastPathComponent
                    guard let data = await readFileData(at: url) else {
                        readError = "Couldn't read that file."
                        return
                    }
                    value = filename
                    onFilePicked(PendingUpload(uploadId: UUID().uuidString, filename: filename, data: data))
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

/// Reads `url`'s contents off the main actor so a large picked file (e.g. a
/// multi-MB wake-word model) doesn't stall the UI. Security-scoped access
/// only needs to be held while the read itself runs.
private func readFileData(at url: URL) async -> Data? {
    await Task.detached(priority: .userInitiated) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }.value
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
