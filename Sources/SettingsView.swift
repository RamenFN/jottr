import SwiftUI
import AVFoundation
import ServiceManagement

// MARK: - Shared Helpers

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private let iso8601DayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appState.selectedSettingsTab = tab
                        }
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.selectedSettingsTab == tab
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.clear)
                                    .animation(.easeInOut(duration: 0.15), value: appState.selectedSettingsTab)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 180)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Group {
                switch appState.selectedSettingsTab {
                case .general, .none:
                    GeneralSettingsView()
                case .intensity:
                    IntensitySettingsView()
                case .snippets:
                    SnippetsSettingsView()
                case .prompts:
                    PromptsSettingsView()
                case .history:
                    RunLogView()
                }
            }
            .id(appState.selectedSettingsTab)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: appState.selectedSettingsTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Intensity Settings

struct IntensitySettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsCard("Default Intensity Level", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Applied at the start of every new recording session.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            ForEach(IntensityLevel.allCases) { level in
                                IntensityOptionRow(
                                    level: level,
                                    isSelected: appState.intensityLevel == level
                                ) {
                                    appState.intensityLevel = level
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct IntensityOptionRow: View {
    let level: IntensityLevel
    let isSelected: Bool
    let action: () -> Void

    private var description: String {
        switch level {
        case .l1: return "Corrects transcription errors only"
        case .l2: return "Removes filler words and redundancy"
        case .l3: return "Rewrites sentences for clarity"
        case .l4: return "Restructures full stream-of-consciousness"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.body)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippets Settings

struct SnippetsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var snippets: [Snippet] = []
    @State private var newTrigger: String = ""
    @State private var newExpansion: String = ""
    @State private var editingSnippetID: UUID? = nil
    @State private var showHelp: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsCard("Snippets", icon: "text.quote") {
                    VStack(alignment: .leading, spacing: 16) {

                        // Help panel — shown when ? is active
                        if showHelp {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Snippets let you say a short trigger phrase and have Jottr automatically replace it with a longer piece of text.")
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                Text("For example: say \"my email\" → Jottr types out your full email address.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            Divider()
                                .transition(.opacity)
                        }

                        // Snippet list
                        if snippets.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No snippets yet")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Use the form below to add your first snippet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Snippets")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                VStack(spacing: 8) {
                                    ForEach(snippets) { snippet in
                                        SnippetRow(
                                            snippet: snippet,
                                            isEditing: editingSnippetID == snippet.id,
                                            onEdit: {
                                                withAnimation(.easeInOut(duration: 0.2)) { editingSnippetID = snippet.id }
                                            },
                                            onCancelEdit: {
                                                withAnimation(.easeInOut(duration: 0.2)) { editingSnippetID = nil }
                                            },
                                            onSaveEdit: { newTrigger, newExpansion in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    appState.updateSnippet(id: snippet.id, trigger: newTrigger, expansion: newExpansion)
                                                    snippets = appState.loadSnippets()
                                                    editingSnippetID = nil
                                                }
                                            },
                                            onDelete: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    appState.removeSnippet(id: snippet.id)
                                                    snippets = appState.loadSnippets()
                                                    if editingSnippetID == snippet.id { editingSnippetID = nil }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        Divider()

                        // Add form
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add New Snippet")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trigger Phrase")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("e.g. my email", text: $newTrigger)
                                    .textFieldStyle(.roundedBorder)
                                if showHelp {
                                    Text("The exact words you'll say to activate this snippet.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expansion Text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("e.g. hello@example.com", text: $newExpansion)
                                    .textFieldStyle(.roundedBorder)
                                if showHelp {
                                    Text("The full text that will be typed out when your trigger is recognized.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            Button("Save Snippet") {
                                appState.addSnippet(trigger: newTrigger, expansion: newExpansion)
                                snippets = appState.loadSnippets()
                                newTrigger = ""
                                newExpansion = ""
                            }
                            .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty || newExpansion.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showHelp.toggle()
                        }
                    } label: {
                        Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                            .foregroundColor(showHelp ? .accentColor : .secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
            .padding(24)
        }
        .onAppear {
            snippets = appState.loadSnippets()
        }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let isEditing: Bool
    let onEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSaveEdit: (String, String) -> Void
    let onDelete: () -> Void

    @State private var editTrigger: String = ""
    @State private var editExpansion: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                VStack(alignment: .leading, spacing: 10) {

                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Editing: \"\(snippet.trigger)\"")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .accessibilityLabel("Delete snippet")
                        }
                        .buttonStyle(.plain)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger Phrase")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Trigger phrase", text: $editTrigger)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expansion Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Expansion text", text: $editExpansion)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Button("Save Changes") {
                            onSaveEdit(editTrigger, editExpansion)
                        }
                        .disabled(editTrigger.trimmingCharacters(in: .whitespaces).isEmpty || editExpansion.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel") {
                            onCancelEdit()
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
                .onAppear {
                    editTrigger = snippet.trigger
                    editExpansion = snippet.expansion
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack {
                    Text(snippet.trigger)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("\u{2192}")
                        .foregroundColor(.secondary)
                    Text(snippet.expansion)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.accentColor)
                            .accessibilityLabel("Edit snippet")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .accessibilityLabel("Delete snippet")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var apiKeyInput: String = ""
    @State private var apiBaseURLInput: String = ""
    @State private var isValidatingKey = false
    @State private var keyValidationError: String?
    @State private var keyValidationSuccess = false
    @State private var customVocabularyInput: String = ""
    @State private var micPermissionGranted = false
    @StateObject private var githubCache = GitHubMetadataCache.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    private let grainRepoURL = URL(string: "https://github.com/RamenFN/jottr")!

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App branding header
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)

                    Text("Jottr")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // GitHub card
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            AsyncImage(url: URL(string: "https://avatars.githubusercontent.com/u/992248")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())

                            Button {
                                openURL(grainRepoURL)
                            } label: {
                                Text("RamenFN/jottr")
                                    .font(.system(.caption, design: .monospaced).weight(.medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                if githubCache.isLoading {
                                    ProgressView().scaleEffect(0.5)
                                } else if let count = githubCache.starCount {
                                    Text("\(count.formatted()) \(count == 1 ? "star" : "stars")")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.yellow.opacity(0.14)))

                            Button {
                                openURL(grainRepoURL)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "star")
                                    Text("Star")
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.yellow.opacity(0.18)))
                            }
                            .buttonStyle(.plain)
                        }

                        if !githubCache.recentStargazers.isEmpty {
                            Divider()
                            HStack(spacing: 8) {
                                HStack(spacing: -6) {
                                    ForEach(githubCache.recentStargazers) { star in
                                        Button {
                                            openURL(star.user.htmlUrl)
                                        } label: {
                                            AsyncImage(url: star.user.avatarThumbnailUrl) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                default:
                                                    Color.gray.opacity(0.2)
                                                }
                                            }
                                            .frame(width: 22, height: 22)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .clipped()
                                Text("recently starred")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize()
                                Spacer()
                            }
                            .clipped()
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 4)

                SettingsCard("Startup", icon: "power") {
                    startupSection
                }
                SettingsCard("Updates", icon: "arrow.triangle.2.circlepath") {
                    updatesSection
                }
                SettingsCard("API Key", icon: "key.fill") {
                    apiKeySection
                }
                SettingsCard("Push-to-Talk Key", icon: "keyboard.fill") {
                    hotkeySection
                }
                SettingsCard("Microphone", icon: "mic.fill") {
                    microphoneSection
                }
                SettingsCard("Custom Vocabulary", icon: "text.book.closed.fill") {
                    vocabularySection
                }
                SettingsCard("Permissions", icon: "lock.shield.fill") {
                    permissionsSection
                }
            }
            .padding(24)
        }
        .onAppear {
            apiKeyInput = appState.apiKey
            apiBaseURLInput = appState.apiBaseURL
            customVocabularyInput = appState.customVocabulary
            checkMicPermission()
            appState.refreshLaunchAtLoginStatus()
            Task { await githubCache.fetchIfNeeded() }
        }
    }

    // MARK: Startup

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch Jottr at login", isOn: $appState.launchAtLogin)

            if SMAppService.mainApp.status == .requiresApproval {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Login item requires approval in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: Updates

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updateManager.autoCheckEnabled },
                set: { updateManager.autoCheckEnabled = $0 }
            ))

            HStack(spacing: 10) {
                Button {
                    Task {
                        await updateManager.checkForUpdates(userInitiated: true)
                    }
                } label: {
                    if updateManager.isChecking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking...")
                        }
                    } else {
                        Text("Check for Updates Now")
                    }
                }
                .disabled(updateManager.isChecking || updateManager.updateStatus != .idle)

                if let lastCheck = updateManager.lastCheckDate {
                    Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if updateManager.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    switch updateManager.updateStatus {
                    case .downloading:
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Downloading update...")
                                    .font(.caption.weight(.semibold))
                                ProgressView(value: updateManager.downloadProgress ?? 0)
                                    .progressViewStyle(.linear)
                                if let progress = updateManager.downloadProgress {
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Cancel") {
                                updateManager.cancelDownload()
                            }
                            .font(.caption)
                        }

                    case .installing:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Installing update...")
                                .font(.caption.weight(.semibold))
                        }

                    case .readyToRelaunch:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Relaunching...")
                                .font(.caption.weight(.semibold))
                        }

                    case .error(let message):
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                            Button("Retry") {
                                updateManager.updateStatus = .idle
                                if let release = updateManager.latestRelease {
                                    updateManager.downloadAndInstall(release: release)
                                }
                            }
                            .font(.caption)
                        }

                    case .idle:
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            Text("A new version of Jottr is available!")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Button("Update Now") {
                                if let release = updateManager.latestRelease {
                                    updateManager.downloadAndInstall(release: release)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jottr uses Groq's whisper-large-v3 model for transcription.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SecureField("Enter your Groq API key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(isValidatingKey)
                    .onChange(of: apiKeyInput) { _ in
                        keyValidationError = nil
                        keyValidationSuccess = false
                    }

                Button(isValidatingKey ? "Validating..." : "Save") {
                    validateAndSaveKey()
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidatingKey)
            }

            if let error = keyValidationError {
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if keyValidationSuccess {
                Label("API key saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Divider()

            Text("API Base URL")
                .font(.caption.weight(.semibold))

            Text("Change this to use a different OpenAI-compatible API provider.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("https://api.groq.com/openai/v1", text: $apiBaseURLInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: apiBaseURLInput) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            appState.apiBaseURL = trimmed
                        }
                    }

                Button("Reset to Default") {
                    apiBaseURLInput = "https://api.groq.com/openai/v1"
                    appState.apiBaseURL = "https://api.groq.com/openai/v1"
                }
                .font(.caption)
            }
        }
    }

    private func validateAndSaveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = apiBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidatingKey = true
        keyValidationError = nil
        keyValidationSuccess = false

        Task {
            let valid = await TranscriptionService.validateAPIKey(key, baseURL: baseURL.isEmpty ? "https://api.groq.com/openai/v1" : baseURL)
            await MainActor.run {
                isValidatingKey = false
                if valid {
                    appState.apiKey = key
                    keyValidationSuccess = true
                } else {
                    keyValidationError = "Invalid API key. Please check and try again."
                }
            }
        }
    }

    // MARK: Push-to-Talk Key

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hold this key to record, release to transcribe.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(HotkeyOption.allCases) { option in
                    HotkeyOptionRow(
                        option: option,
                        isSelected: appState.selectedHotkey == option,
                        action: {
                            appState.selectedHotkey = option
                        }
                    )
                }
            }

            if appState.selectedHotkey == .fnKey {
                Text("Tip: If Fn opens Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Microphone

    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select which microphone to use for recording.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                MicrophoneOptionRow(
                    name: "System Default",
                    isSelected: appState.selectedMicrophoneID == "default" || appState.selectedMicrophoneID.isEmpty,
                    action: { appState.selectedMicrophoneID = "default" }
                )
                ForEach(appState.availableMicrophones) { device in
                    MicrophoneOptionRow(
                        name: device.name,
                        isSelected: appState.selectedMicrophoneID == device.uid,
                        action: { appState.selectedMicrophoneID = device.uid }
                    )
                }
            }
        }
        .onAppear {
            appState.refreshAvailableMicrophones()
        }
    }

    // MARK: Custom Vocabulary

    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Words and phrases to preserve during post-processing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $customVocabularyInput)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: customVocabularyInput) { newValue in
                    appState.customVocabulary = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }

            Text("Separate entries with commas, new lines, or semicolons.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            permissionRow(
                title: "Microphone",
                icon: "mic.fill",
                granted: micPermissionGranted,
                action: {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            micPermissionGranted = granted
                        }
                    }
                }
            )

            permissionRow(
                title: "Accessibility",
                icon: "hand.raised.fill",
                granted: appState.hasAccessibility,
                action: {
                    appState.openAccessibilitySettings()
                }
            )

            permissionRow(
                title: "Screen Recording",
                icon: "camera.viewfinder",
                granted: appState.hasScreenRecordingPermission,
                action: {
                    appState.requestScreenCapturePermission()
                }
            )
        }
    }

    private func permissionRow(title: String, icon: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(title)
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Granted")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    action()
                }
                .font(.caption)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func checkMicPermission() {
        micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

}

// MARK: - Microphone Option Row

struct MicrophoneOptionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prompts Settings

struct PromptsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var customContextPromptInput: String = ""
    @State private var showDefaultContextPrompt = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(IntensityLevel.allCases) { level in
                    PerLevelPromptCard(level: level)
                }

                SettingsCard("Context Prompt", icon: "eye.fill") {
                    contextPromptSection
                }
            }
            .padding(24)
        }
        .onAppear {
            customContextPromptInput = appState.customContextPrompt.isEmpty
                ? AppContextService.defaultContextPrompt
                : appState.customContextPrompt
        }
    }

    // MARK: Context Prompt

    private var contextPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions for how the screen context is summarized before being sent to the model.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $customContextPromptInput)
                .font(.body.monospaced())
                .frame(minHeight: 120, maxHeight: 200)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: customContextPromptInput) { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty || trimmed == AppContextService.defaultContextPrompt {
                        appState.customContextPrompt = ""
                    } else {
                        appState.customContextPrompt = trimmed
                        appState.customContextPromptLastModified = iso8601DayFormatter.string(from: Date())
                    }
                }

            HStack {
                if appState.customContextPrompt.isEmpty {
                    Label("Using default", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Using custom prompt", systemImage: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Spacer()
                if !appState.customContextPrompt.isEmpty {
                    Button("Reset to Default") {
                        appState.customContextPrompt = ""
                        customContextPromptInput = AppContextService.defaultContextPrompt
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }

}

// MARK: - Per-Level Prompt Card

private struct PerLevelPromptCard: View {
    let level: IntensityLevel
    @EnvironmentObject var appState: AppState
    @State private var promptInput: String = ""

    private var isCustom: Bool {
        !appState.customPrompt(for: level).isEmpty
    }

    var body: some View {
        SettingsCard(level.displayName, icon: "text.bubble.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt used when dictating at \(level.rawValue) intensity.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $promptInput)
                    .font(.body.monospaced())
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: promptInput) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed == level.systemPrompt {
                            appState.setCustomPrompt("", for: level)
                        } else {
                            appState.setCustomPrompt(trimmed, for: level)
                        }
                    }

                HStack {
                    if isCustom {
                        Label("Using custom prompt", systemImage: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Label("Using default", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isCustom {
                        Button("Reset to Default") {
                            appState.setCustomPrompt("", for: level)
                            promptInput = level.systemPrompt
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .onAppear {
            let custom = appState.customPrompt(for: level)
            promptInput = custom.isEmpty ? level.systemPrompt : custom
        }
    }
}

// MARK: - Run Log

struct RunLogView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run Log")
                        .font(.headline)
                    Text("Stored locally. Only the \(appState.maxPipelineHistoryCount) most recent runs are kept.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Clear History") {
                    appState.clearPipelineHistory()
                }
                .disabled(appState.pipelineHistory.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if appState.pipelineHistory.isEmpty {
                VStack {
                    Spacer()
                    Text("No runs yet. Use dictation to populate history.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.pipelineHistory) { item in
                            RunLogEntryView(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - Run Log Entry

struct RunLogEntryView: View {
    let item: PipelineHistoryItem
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @State private var showContextPrompt = false
    @State private var showPostProcessingPrompt = false

    private var isError: Bool {
        item.postProcessingStatus.hasPrefix("Error:")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        if isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.subheadline.weight(.semibold))
                            Text(item.postProcessedTranscript.isEmpty ? "(no transcript)" : item.postProcessedTranscript)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.deleteHistoryEntry(id: item.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete this run")
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Audio player
                    if let audioFileName = item.audioFileName {
                        let audioURL = AppState.audioStorageDirectory().appendingPathComponent(audioFileName)
                        AudioPlayerView(audioURL: audioURL)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("No audio recorded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Custom vocabulary
                    if !item.customVocabulary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Vocabulary")
                                .font(.caption.weight(.semibold))
                            FlowLayout(spacing: 4) {
                                ForEach(parseVocabulary(item.customVocabulary), id: \.self) { word in
                                    Text(word)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Pipeline steps
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pipeline")
                            .font(.caption.weight(.semibold))

                        // Step 1: Context Capture
                        PipelineStepView(
                            number: 1,
                            title: "Capture Context",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let dataURL = item.contextScreenshotDataURL,
                                       let image = imageFromDataURL(dataURL) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 120)
                                            .cornerRadius(4)
                                    }

                                    if let prompt = item.contextPrompt, !prompt.isEmpty {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showContextPrompt.toggle()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showContextPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: "chevron.down")
                                                    .font(.caption2)
                                                    .rotationEffect(.degrees(showContextPrompt ? 180 : 0))
                                                    .animation(.easeInOut(duration: 0.2), value: showContextPrompt)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showContextPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(nsColor: .controlBackgroundColor))
                                                .cornerRadius(4)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }

                                    if !item.contextSummary.isEmpty {
                                        Text(item.contextSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    } else {
                                        Text("No context captured")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 2: Transcribe Audio
                        PipelineStepView(
                            number: 2,
                            title: "Transcribe Audio",
                            content: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sent audio to Groq whisper-large-v3")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    if !item.rawTranscript.isEmpty {
                                        Text(item.rawTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(4)
                                    } else {
                                        Text("(empty transcript)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 3: Post-Process
                        PipelineStepView(
                            number: 3,
                            title: "Post-Process",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.postProcessingStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)

                                    if let prompt = item.postProcessingPrompt, !prompt.isEmpty {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showPostProcessingPrompt.toggle()
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showPostProcessingPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: "chevron.down")
                                                    .font(.caption2)
                                                    .rotationEffect(.degrees(showPostProcessingPrompt ? 180 : 0))
                                                    .animation(.easeInOut(duration: 0.2), value: showPostProcessingPrompt)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showPostProcessingPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(nsColor: .controlBackgroundColor))
                                                .cornerRadius(4)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }

                                    if !item.postProcessedTranscript.isEmpty {
                                        Text(item.postProcessedTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isError ? Color.red.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func parseVocabulary(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Pipeline Step View

struct PipelineStepView<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Audio Player

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVAudioPlayer?
    @State private var delegate = AudioPlayerDelegate()
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var elapsed: TimeInterval = 0
    @State private var progressTimer: Timer?

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 28)

            Text("\(formatDuration(elapsed)) / \(formatDuration(duration))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .onAppear {
            loadDuration()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func loadDuration() {
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
        if let p = try? AVAudioPlayer(contentsOf: audioURL) {
            duration = p.duration
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
            do {
                let p = try AVAudioPlayer(contentsOf: audioURL)
                delegate.onFinish = {
                    self.stopPlayback()
                }
                p.delegate = delegate
                p.play()
                player = p
                isPlaying = true
                elapsed = 0
                startProgressTimer()
            } catch {}
        }
    }

    private func stopPlayback() {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        elapsed = 0
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let p = player, p.isPlaying {
                elapsed = p.currentTime
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let pos = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

