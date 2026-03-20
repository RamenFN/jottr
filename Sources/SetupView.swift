import SwiftUI
import AVFoundation
import Combine
import Foundation
import ServiceManagement

struct SetupView: View {
    var onComplete: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    private let grainRepoURL = URL(string: "https://github.com/RamenFN/jottr")!
    private enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case apiKey
        case micPermission
        case micIndicator       // NEW
        case accessibility
        case screenRecording
        case hotkey
        case vocabulary
        case launchAtLogin
        case testTranscription
        case ready
    }

    @State private var currentStep = SetupStep.welcome
    @State private var goingForward = true
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var apiKeyInput: String = ""
    @State private var isValidatingKey = false
    @State private var keyValidationError: String?
    @State private var accessibilityTimer: Timer?
    @State private var screenRecordingTimer: Timer?
    @State private var customVocabularyInput: String = ""
    @StateObject private var githubCache = GitHubMetadataCache.shared
    @State private var isHoveringSkip = false
    @State private var isHoveringBack = false

    // Test transcription state
    private enum TestPhase: Equatable {
        case idle, recording, transcribing, done
    }
    @State private var testPhase: TestPhase = .idle
    @State private var testAudioRecorder: AudioRecorder? = nil
    @State private var testAudioLevel: Float = 0.0
    @State private var testRawTranscript: String = ""
    @State private var testTranscript: String = ""
    @State private var testError: String? = nil
    @State private var testAudioLevelCancellable: AnyCancellable? = nil
    @State private var testMicPulsing = false
    @State private var selectedTestLevel: IntensityLevel = .l2

    private var readingScripts: [IntensityLevel: String] {
        [
            .l1: "um the meeting tomorrow is at three pm can you send me the uh agenda beforehand i think sarah is presenting",
            .l2: "so basically i i wanted to say that the project is kind of sort of done we just need to basically finalize the the last few things before we can uh ship it to the team",
            .l3: "i was thinking that like the reason the onboarding is kind of confusing is probably because we we never actually you know tested it with real users and so um we should probably do that before we uh launch it",
            .l4: "okay so the thing is the product is good i think it's good anyway but users just aren't converting and i keep thinking it's the pricing but then maybe it's the onboarding or maybe we need better copy on the landing page actually the landing page might be the main issue people land there and they don't know what we do"
        ]
    }

    private let totalSteps: [SetupStep] = SetupStep.allCases

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots at top
            SetupProgressDots(currentStep: currentStep, allSteps: totalSteps)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Amber header bar — full width
            Rectangle()
                .fill(JottrTheme.amber)
                .frame(height: 4)

            // Step content with directional slide
            ZStack {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .apiKey:
                    apiKeyStep
                case .micPermission:
                    micPermissionStep
                case .micIndicator:
                    micIndicatorStep
                case .accessibility:
                    accessibilityStep
                case .screenRecording:
                    screenRecordingStep
                case .hotkey:
                    hotkeyStep
                case .vocabulary:
                    vocabularyStep
                case .launchAtLogin:
                    launchAtLoginStep
                case .testTranscription:
                    testTranscriptionStep
                case .ready:
                    readyStep
                }
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading),
                removal: .move(edge: goingForward ? .leading : .trailing)
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
            .clipped()

            Divider()
                .padding(.top, 8)

            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        keyValidationError = nil
                        isHoveringBack = false
                        goingForward = false
                        withAnimation(.easeInOut(duration: 0.28)) {
                            currentStep = previousStep(currentStep)
                        }
                    }
                    .disabled(isValidatingKey)
                    .buttonStyle(.plain)
                    .foregroundStyle(isHoveringBack ? JottrTheme.amber : JottrTheme.textPrimary)
                    .font(.headline.weight(.semibold))
                    .onHover { isHoveringBack = $0 }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                Spacer()
                if currentStep != .ready {
                    if currentStep == .apiKey {
                        // API key step: validate before continuing
                        Button {
                            validateAndContinue()
                        } label: {
                            Text(isValidatingKey ? "Validating..." : "Continue")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JottrTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JottrTheme.amber))
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidatingKey)
                        .buttonStyle(.plain)
                    } else if currentStep == .vocabulary {
                        Button {
                            isHoveringSkip = false
                            goingForward = true
                            withAnimation(.easeInOut(duration: 0.28)) {
                                currentStep = nextStep(currentStep)
                            }
                        } label: {
                            Text("Skip for now")
                                .foregroundStyle(isHoveringSkip ? JottrTheme.amber : JottrTheme.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringSkip = $0 }

                        Button {
                            saveCustomVocabularyAndContinue()
                        } label: {
                            Text("Continue")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JottrTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JottrTheme.amber))
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.plain)
                    } else if currentStep == .testTranscription {
                        Button {
                            stopTestHotkeyMonitoring()
                            goingForward = true
                            withAnimation(.easeInOut(duration: 0.28)) {
                                currentStep = nextStep(currentStep)
                            }
                        } label: {
                            Text("Skip")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.intensityLevel = selectedTestLevel
                            stopTestHotkeyMonitoring()
                            goingForward = true
                            withAnimation(.easeInOut(duration: 0.28)) {
                                currentStep = nextStep(currentStep)
                            }
                        } label: {
                            Text("Continue")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JottrTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JottrTheme.amber))
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(testPhase != .done || testTranscript.isEmpty || testError != nil)
                        .buttonStyle(.plain)
                    } else {
                        // Only show "Skip for now" on Mac permission steps
                        if currentStep == .micPermission || currentStep == .accessibility || currentStep == .screenRecording {
                            Button {
                                isHoveringSkip = false
                                goingForward = true
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    currentStep = nextStep(currentStep)
                                }
                            } label: {
                                Text("Skip for now")
                                    .foregroundStyle(isHoveringSkip ? JottrTheme.amber : JottrTheme.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveringSkip = $0 }
                        }

                        Button {
                            goingForward = true
                            withAnimation(.easeInOut(duration: 0.28)) {
                                currentStep = nextStep(currentStep)
                            }
                        } label: {
                            Text("Continue")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JottrTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(JottrTheme.amber))
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canContinueFromCurrentStep)
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        onComplete()
                    } label: {
                        Text("Get Started")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(JottrTheme.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(JottrTheme.amber))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 580, height: 660)
        .background(JottrTheme.background)
        .onAppear {
            apiKeyInput = appState.apiKey
            customVocabularyInput = appState.customVocabulary
            checkMicPermission()
            checkAccessibility()
            Task {
                await githubCache.fetchIfNeeded()
            }
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            screenRecordingTimer?.invalidate()
        }
    }

    // MARK: - Steps

    var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            VStack(spacing: 6) {
                Text("Welcome to Jottr")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(JottrTheme.textPrimary)

                Text("Dictate text anywhere on your Mac.\nHold a key to record, release to transcribe.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: "https://github.com/RamenFN.png")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())

                    Button {
                        openURL(grainRepoURL)
                    } label: {
                        Text("RamenFN/jottr")
                            .font(.system(.caption, design: .monospaced).weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(JottrTheme.amber)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(JottrTheme.amber)
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
                    .background(Capsule().fill(JottrTheme.amber.opacity(0.12)))

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
                        .background(Capsule().fill(JottrTheme.amber.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
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
    }

    var apiKeyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Groq API Key")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Jottr uses Groq for fast, high-accuracy transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to get a free API key:")
                        .font(.subheadline.weight(.semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        instructionRow(number: "1", text: "Go to [console.groq.com/keys](https://console.groq.com/keys)")
                        instructionRow(number: "2", text: "Create a free account (if you don't have one)")
                        instructionRow(number: "3", text: "Click **Create API Key** and copy it")
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(JottrTheme.amber.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.headline)
                    SecureField("Paste your Groq API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(isValidatingKey)
                        .onChange(of: apiKeyInput) { _ in
                            keyValidationError = nil
                        }

                    if let error = keyValidationError {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
    }

    var micPermissionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Jottr needs access to your microphone to record audio for transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "mic.fill")
                    .frame(width: 24)
                    .foregroundStyle(JottrTheme.amber)
                Text("Microphone")
                Spacer()
                if micPermissionGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Granted")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        requestMicPermission()
                    } label: {
                        Text("Grant Access")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JottrTheme.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(JottrTheme.amber.opacity(0.12)))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    var micIndicatorStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Persistent Mic Indicator")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("macOS shows an orange dot in the menu bar whenever a microphone is active.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            Toggle("Show persistent mic indicator", isOn: $appState.keepMicIndicatorAlive)
                .tint(JottrTheme.amber)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(JottrTheme.amber)
                    .font(.caption)
                Text("Disabling may cause a brief audio pause at the start of your next recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(JottrTheme.amber.opacity(0.08))
            .cornerRadius(8)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("This keeps the mic active for a smoother experience — Jottr never records audio unless you hold the hotkey. This is a temporary workaround while we find a better solution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    var accessibilityStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Jottr needs Accessibility access to paste transcribed text into your apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "hand.raised.fill")
                    .frame(width: 24)
                    .foregroundStyle(JottrTheme.amber)
                Text("Accessibility")
                Spacer()
                if accessibilityGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Granted")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        requestAccessibility()
                    } label: {
                        Text("Open Settings")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JottrTheme.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(JottrTheme.amber.opacity(0.12)))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if !accessibilityGranted {
                Text("Note: If you rebuilt the app, you may need to\nremove and re-add it in Accessibility settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
        .onAppear {
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
        }
    }

    var screenRecordingStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Screen Recording")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Jottr intelligently adapts the transcription to the current app you're working in (ex. spelling names in an email correctly).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("It needs this permission to see which app you're working in and any in-progress work. Screenshots are processed locally on your Mac and never sent to any server — Jottr has no servers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "camera.viewfinder")
                    .frame(width: 24)
                    .foregroundStyle(JottrTheme.amber)
                Text("Screen Recording")
                Spacer()
                if appState.hasScreenRecordingPermission {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Granted")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        appState.requestScreenCapturePermission()
                    } label: {
                        Text("Grant Access")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JottrTheme.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(JottrTheme.amber.opacity(0.12)))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .onAppear {
            startScreenRecordingPolling()
        }
        .onDisappear {
            screenRecordingTimer?.invalidate()
        }
    }

    var hotkeyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Push-to-Talk Key")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Choose which key to hold while speaking.\nPress and hold to record, release to transcribe.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
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
            .padding(.top, 10)

            if appState.selectedHotkey == .fnKey {
                Text("Tip: If Fn opens Emoji picker, go to\nSystem Settings > Keyboard and change\n\"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(JottrTheme.amber)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
    }

    var vocabularyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Custom Vocabulary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Add words and phrases that should be preserved in post-processing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Vocabulary")
                    .font(.headline)

                TextEditor(text: $customVocabularyInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Separate entries with commas, new lines, or semicolons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
    }

    var launchAtLoginStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 60))
                .foregroundStyle(JottrTheme.amber)

            Text("Launch at Login")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Start Jottr automatically when you log in so it's always ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "sunrise.fill")
                    .frame(width: 24)
                    .foregroundStyle(JottrTheme.amber)
                Toggle("Launch Jottr at login", isOn: $appState.launchAtLogin)
                    .tint(JottrTheme.amber)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    var testTranscriptionStep: some View {
        ScrollView {
            VStack(spacing: 20) {
            // Microphone picker
            VStack(spacing: 4) {
                Picker("Microphone:", selection: $appState.selectedMicrophoneID) {
                    Text("System Default").tag("default")
                    ForEach(appState.availableMicrophones) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .frame(maxWidth: 340)

                Text("You can change this later in the menu bar or settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }

            // Intensity picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Rewriting Level")
                    .font(.headline)

                HStack(spacing: 6) {
                    ForEach(IntensityLevel.allCases, id: \.self) { level in
                        Button {
                            selectedTestLevel = level
                        } label: {
                            Text(level.selectorLabel)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(selectedTestLevel == level ? JottrTheme.amber : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule().fill(selectedTestLevel == level
                                        ? JottrTheme.amber.opacity(0.12)
                                        : Color.clear)
                                )
                                .overlay(
                                    Capsule().stroke(selectedTestLevel == level
                                        ? JottrTheme.amber.opacity(0.4)
                                        : Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: selectedTestLevel)
                    }
                }

                Text(selectedTestLevel.selectorDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.15), value: selectedTestLevel)
            }

            // Reading script card
            VStack(alignment: .leading, spacing: 4) {
                Text("Try saying:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Text(readingScripts[selectedTestLevel] ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Group {
                switch testPhase {
                case .idle:
                    VStack(spacing: 20) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(JottrTheme.amber)
                            .scaleEffect(testMicPulsing ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: testMicPulsing)

                        Text("Let's Try It Out!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Hold **\(appState.selectedHotkey.displayName)**")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(JottrTheme.amber.opacity(0.12))
                            .cornerRadius(10)

                        Text("Say anything — a sentence or two is perfect.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }

                case .recording:
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(JottrTheme.amber.opacity(0.65))
                                .frame(width: 100, height: 100)

                            Circle()
                                .stroke(JottrTheme.amber.opacity(0.8), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .shadow(color: JottrTheme.amber.opacity(0.5), radius: 10)

                            WaveformView(audioLevel: testAudioLevel)
                        }

                        Text("Listening...")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(JottrTheme.amber)
                    }

                case .transcribing:
                    VStack(spacing: 20) {
                        InlineTranscribingDots()

                        Text("Transcribing...")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }

                case .done:
                    VStack(spacing: 16) {
                        if let error = testError {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.red)

                            Text("Something went wrong")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)

                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)

                            Text(testTranscript.isEmpty ? "No speech detected" : "Perfect — Jottr is ready to go.")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(testTranscript.isEmpty ? .secondary : .primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                        }

                        Text("Hold **\(appState.selectedHotkey.displayName)** to try again")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                    }
                }
            }
            .transition(.opacity)
            .id(testPhase)

            // Persistent result area — always visible
            VStack(alignment: .leading, spacing: 8) {
                if testTranscript.isEmpty {
                    // Placeholder
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        Text("Your result will appear here after recording...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(12)
                    }
                    .frame(minHeight: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Jottr output (\(selectedTestLevel.selectorLabel))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JottrTheme.amber)
                            Spacer()
                        }
                        Text(testTranscript)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(JottrTheme.amber.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(JottrTheme.amber.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: testTranscript.isEmpty)

            } // end inner VStack
        } // end ScrollView
        .onAppear {
            appState.refreshAvailableMicrophones()
            testMicPulsing = true
            startTestHotkeyMonitoring()
        }
        .onDisappear {
            stopTestHotkeyMonitoring()
        }
    }

    var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(JottrTheme.textPrimary)

            Text("Jottr lives in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            VStack(alignment: .leading, spacing: 12) {
                HowToRow(icon: "keyboard", text: "Hold \(appState.selectedHotkey.displayName) to record")
                HowToRow(icon: "hand.raised", text: "Release to stop and transcribe")
                HowToRow(icon: "doc.on.clipboard", text: "Text is typed at your cursor & copied")
            }
            .padding(.top, 4)

            // Pro tip card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(JottrTheme.amber)
                        .font(.subheadline)
                    Text("Pro tip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JottrTheme.amber)
                }

                Text("For best results, click into the text field you want to dictate into **before** holding the key — Jottr will type directly at your cursor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Accidentally switched tabs? No worries — your transcription is always saved to your clipboard. Just press **⌘V** to paste it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(JottrTheme.amber.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(JottrTheme.amber.opacity(0.18), lineWidth: 1)
                    )
            )
        }
    }

    private var canContinueFromCurrentStep: Bool {
        switch currentStep {
        case .micPermission:
            return micPermissionGranted
        case .accessibility:
            return accessibilityGranted
        case .screenRecording:
            return appState.hasScreenRecordingPermission
        case .testTranscription:
            return testPhase == .done && !testTranscript.isEmpty && testError == nil
        default:
            return true
        }
    }

    // MARK: - Helpers

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number + ".")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.subheadline)
                .tint(JottrTheme.amber)
        }
    }

    // MARK: - Actions

    func validateAndContinue() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidatingKey = true
        keyValidationError = nil

        Task {
            let valid = await TranscriptionService.validateAPIKey(key, baseURL: appState.apiBaseURL)
            await MainActor.run {
                isValidatingKey = false
                if valid {
                    appState.apiKey = key
                    goingForward = true
                    withAnimation(.easeInOut(duration: 0.28)) {
                        currentStep = nextStep(currentStep)
                    }
                } else {
                    keyValidationError = "Invalid API key. Please check and try again."
                }
            }
        }
    }

    func saveCustomVocabularyAndContinue() {
        appState.customVocabulary = customVocabularyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        goingForward = true
        withAnimation(.easeInOut(duration: 0.28)) {
            currentStep = nextStep(currentStep)
        }
    }

    private func previousStep(_ step: SetupStep) -> SetupStep {
        let previous = SetupStep(rawValue: step.rawValue - 1)
        return previous ?? .welcome
    }

    private func nextStep(_ step: SetupStep) -> SetupStep {
        let next = SetupStep(rawValue: step.rawValue + 1)
        return next ?? .ready
    }

    func checkMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micPermissionGranted = true
        default:
            break
        }
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
            }
        }
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                checkAccessibility()
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func startScreenRecordingPolling() {
        screenRecordingTimer?.invalidate()
        screenRecordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                appState.hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
            }
        }
    }

    // MARK: - Test Transcription

    private func startTestHotkeyMonitoring() {
        appState.hotkeyManager.onKeyDown = { [self] in
            DispatchQueue.main.async {
                guard testPhase == .idle || testPhase == .done else { return }
                if testPhase == .done {
                    resetTest()
                }
                appState.intensityLevel = selectedTestLevel
                do {
                    let recorder = AudioRecorder()
                    try recorder.startRecording(deviceUID: appState.selectedMicrophoneID)
                    testAudioRecorder = recorder
                    testAudioLevelCancellable = recorder.$audioLevel
                        .receive(on: DispatchQueue.main)
                        .sink { level in
                            testAudioLevel = level
                        }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .recording
                    }
                } catch {
                    testError = error.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .done
                    }
                }
            }
        }

        appState.hotkeyManager.onKeyUp = { [self] in
            DispatchQueue.main.async {
                guard testPhase == .recording, let recorder = testAudioRecorder else { return }
                let fileURL = recorder.stopRecording()
                testAudioLevelCancellable?.cancel()
                testAudioLevelCancellable = nil
                testAudioLevel = 0.0

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    testPhase = .transcribing
                }

                guard let url = fileURL else {
                    testError = "No audio file was created."
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .done
                    }
                    return
                }

                let capturedLevel = selectedTestLevel
                Task {
                    do {
                        let transcriptionService = TranscriptionService(apiKey: appState.apiKey, baseURL: appState.apiBaseURL)
                        let rawTranscript = try await transcriptionService.transcribe(fileURL: url)

                        // Run post-processing at the selected intensity level
                        let postProcessor = PostProcessingService(apiKey: appState.apiKey, baseURL: appState.apiBaseURL)
                        let emptyContext = AppContext(appName: nil, bundleIdentifier: nil, windowTitle: nil, selectedText: nil, currentActivity: "", contextPrompt: nil, screenshotDataURL: nil, screenshotMimeType: nil, screenshotError: nil)
                        let result = try await postProcessor.postProcess(
                            transcript: rawTranscript,
                            context: emptyContext,
                            customVocabulary: appState.customVocabulary,
                            customSystemPrompt: capturedLevel.systemPrompt
                        )

                        await MainActor.run {
                            testRawTranscript = rawTranscript
                            testTranscript = result.transcript.isEmpty ? rawTranscript : result.transcript
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                testPhase = .done
                            }
                        }
                    } catch {
                        await MainActor.run {
                            testError = error.localizedDescription
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                testPhase = .done
                            }
                        }
                    }
                    // Clean up temp file
                    recorder.cleanup()
                }
            }
        }

        appState.hotkeyManager.start(option: appState.selectedHotkey)
    }

    private func stopTestHotkeyMonitoring() {
        appState.hotkeyManager.stop()
        appState.hotkeyManager.onKeyDown = nil
        appState.hotkeyManager.onKeyUp = nil
        testAudioLevelCancellable?.cancel()
        testAudioLevelCancellable = nil
        if let recorder = testAudioRecorder, recorder.isRecording {
            _ = recorder.stopRecording()
            recorder.cleanup()
        }
        testAudioRecorder = nil
    }

    private func resetTest() {
        testPhase = .idle
        testRawTranscript = ""
        testTranscript = ""
        testError = nil
        testAudioLevel = 0.0
        testMicPulsing = true
        if let recorder = testAudioRecorder {
            if recorder.isRecording {
                _ = recorder.stopRecording()
            }
            recorder.cleanup()
            testAudioRecorder = nil
        }
    }

}

// MARK: - SetupProgressDots

private struct SetupProgressDots<Step: RawRepresentable & Equatable>: View where Step.RawValue == Int {
    let currentStep: Step
    let allSteps: [Step]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(allSteps.indices, id: \.self) { index in
                let step = allSteps[index]
                Circle()
                    .fill(dotFill(for: step))
                    .overlay(
                        Circle()
                            .stroke(dotStroke(for: step), lineWidth: step.rawValue < currentStep.rawValue ? 1.5 : 0)
                    )
                    .frame(width: dotSize(for: step), height: dotSize(for: step))
            }
        }
    }

    private func dotFill(for step: Step) -> Color {
        if step == currentStep {
            return JottrTheme.amber // active: amber filled
        } else if step.rawValue < currentStep.rawValue {
            return Color.clear // completed: amber outlined (stroke only)
        } else {
            return Color.gray.opacity(0.3) // future: gray
        }
    }

    private func dotStroke(for step: Step) -> Color {
        if step.rawValue < currentStep.rawValue {
            return JottrTheme.amber // completed: amber outline
        }
        return Color.clear
    }

    private func dotSize(for step: Step) -> CGFloat {
        (step == currentStep || step.rawValue < currentStep.rawValue) ? 8 : 6
    }
}

struct GitHubRepoInfo: Decodable {
    let stargazersCount: Int

    private enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
    }
}


@MainActor
class GitHubMetadataCache: ObservableObject {
    static let shared = GitHubMetadataCache()

    @Published var starCount: Int?
    @Published var isLoading = true

    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 5 * 60 // 5 minutes
    private let repoAPIURL = URL(string: "https://api.github.com/repos/RamenFN/jottr")!

    private init() {}

    func fetchIfNeeded() async {
        if let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return
        }

        isLoading = true

        do {
            let repoResult = try await URLSession.shared.data(from: repoAPIURL)
            guard let repoHTTP = repoResult.1 as? HTTPURLResponse,
                  (200..<300).contains(repoHTTP.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let count = try JSONDecoder().decode(GitHubRepoInfo.self, from: repoResult.0).stargazersCount

            starCount = count
            isLoading = false
            lastFetchDate = Date()
        } catch {
            isLoading = false
        }
    }
}

private struct InlineTranscribingDots: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(JottrTheme.amber.opacity(activeDot == index ? 1.0 : 0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

struct HotkeyOptionRow: View {
    let option: HotkeyOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? JottrTheme.amber : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                Text(option.displayName)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? JottrTheme.amber.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? JottrTheme.amber : Color.clear, lineWidth: 1.5)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HowToRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(JottrTheme.amber)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
