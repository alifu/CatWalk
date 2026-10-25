#if CATWALK_ENABLED
//
//  CWSettingsView.swift
//  CatWalk
//

import SwiftUI

/// Capture switch, ignored hosts and memory usage.
struct CWSettingsView: View {

    let store: CWTransactionStore

    @State private var isCapturing = CatWalk.isRunning
    @State private var hosts = CatWalk.ignoredHosts
    @State private var newHost = ""
    @State private var errorMessage: String?
    @State private var options = CWCaptureEngine.shared.recorder.configuration

    var body: some View {
        Form {
            Section {
                Toggle("Capture requests", isOn: Binding(
                    get: { isCapturing },
                    set: { CWCaptureEngine.shared.setCapturing($0); isCapturing = CatWalk.isRunning }
                ))
            }
            Section("Sources") {
                #if !CATWALK_EXCLUDE_WEBSOCKET
                optionToggle("WebSockets", \.captureWebSockets)
                #endif
                #if !CATWALK_EXCLUDE_MEDIA
                optionToggle("AVPlayer media", \.captureMedia)
                #endif
                #if !CATWALK_EXCLUDE_WEBVIEW
                optionToggle("Instrument new web views", \.instrumentWebViews)
                optionToggle("Inspectable web views", \.makeWebViewsInspectable)
                #endif
                row("Early install", CWBootstrap.didRunAtLoad ? "Active" : (CWBootstrap.isEarlyInstallEnabled ? "Did not run" : "Off"))
                #if !CATWALK_EXCLUDE_WEBVIEW
                Text("Web view switches apply to web views created from now on.").font(.caption).foregroundColor(.secondary)
                #endif
            }
            Section("Ignored hosts") {
                ForEach(hosts, id: \.self) { Text($0) }
                    .onDelete { offsets in
                        offsets.map { hosts[$0] }.forEach { try? CatWalk.unignore(host: $0) }
                        hosts = CatWalk.ignoredHosts
                    }
                HStack {
                    TextField("api.example.com or *.example.com", text: $newHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit(add)
                    Button("Add", action: add).disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let errorMessage { Text(errorMessage).font(.caption).foregroundColor(.red) }
            }
            Section("Memory") {
                row("Requests", "\(store.count) of \(store.capacity)")
                row(
                    "Bodies",
                    "\(CWFormat.bytes(store.totalBodyBytes)) of \(CWFormat.bytes(CWCaptureEngine.shared.recorder.configuration.maxTotalBodyBytes))"
                )
                Text("Everything is kept in memory and erased when the app exits.").font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func optionToggle(_ title: String, _ keyPath: WritableKeyPath<CWConfiguration, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { options[keyPath: keyPath] },
            set: { value in
                CWCaptureEngine.shared.updateConfiguration { $0[keyPath: keyPath] = value }
                options = CWCaptureEngine.shared.recorder.configuration
            }
        ))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func add() {
        do {
            try CatWalk.ignore(host: newHost)
            newHost = ""
            errorMessage = nil
            hosts = CatWalk.ignoredHosts
        } catch {
            errorMessage = "Not a valid host rule."
        }
    }
}
#endif
