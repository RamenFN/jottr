import SwiftUI
import AppKit

// MARK: - State

class RecordingOverlayState: ObservableObject {
    @Published var phase: OverlayPhase = .recording
    @Published var audioLevel: Float = 0.0
    @Published var intensityLevel: IntensityLevel = .l2
    @Published var isIntensityFlashing: Bool = false
}

enum OverlayPhase {
    case initializing
    case recording
    case transcribing
    case done
}

// MARK: - Panel Helpers

private func makeOverlayPanel(width: CGFloat, height: CGFloat) -> NSPanel {
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.level = .screenSaver
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces]
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    return panel
}

/// Wraps a SwiftUI view in an NSView for use as panel content.
private func makeNotchContent<V: View>(
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat,
    rootView: V
) -> NSView {
    let shaped = rootView
        .frame(width: width, height: height)
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius))

    let hosting = NSHostingView(rootView: shaped)
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
    hosting.autoresizingMask = [.width, .height]
    return hosting
}

// MARK: - Manager

class RecordingOverlayManager {
    private var overlayWindow: NSPanel?
    private var transcribingPanel: NSPanel?
    private var overlayState = RecordingOverlayState()

    /// Whether the main screen has a camera housing (notch).
    private var screenHasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }

    /// Width of the camera housing (notch) in points, or 0 if no notch.
    private var notchWidth: CGFloat {
        guard let screen = NSScreen.main, screenHasNotch else { return 0 }
        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else { return 0 }
        return screen.frame.width - leftArea.width - rightArea.width
    }

    func showInitializing() {
        DispatchQueue.main.async {
            self.overlayState.phase = .initializing
            self.overlayState.audioLevel = 0.0
            self._showOverlayPanel()
        }
    }

    func showRecording() {
        DispatchQueue.main.async {
            self.overlayState.phase = .recording
            self.overlayState.audioLevel = 0.0
            self._showOverlayPanel()
        }
    }

    func transitionToRecording() {
        DispatchQueue.main.async { self.overlayState.phase = .recording }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { self.overlayState.audioLevel = level }
    }

    func setIntensityLevel(_ level: IntensityLevel) {
        DispatchQueue.main.async {
            self.overlayState.intensityLevel = level
        }
    }

    func flashIntensityChange() {
        DispatchQueue.main.async {
            guard let panel = self.overlayWindow,
                  let _ = NSScreen.main else { return }
            let currentFrame = panel.frame
            // Drop DOWN into view, then spring back up past center and settle
            let droppedFrame = NSRect(x: currentFrame.origin.x,
                                      y: currentFrame.origin.y - 10,
                                      width: currentFrame.width,
                                      height: currentFrame.height)

            // Amber flash inside the pill
            self.overlayState.isIntensityFlashing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.overlayState.isIntensityFlashing = false
            }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(droppedFrame, display: true)
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.26
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
                    panel.animator().setFrame(currentFrame, display: true)
                }
            }
        }
    }

    func showTranscribing() {
        DispatchQueue.main.async { self._showTranscribing() }
    }

    func slideUpToNotch(completion: @escaping () -> Void) {
        DispatchQueue.main.async { self._slideUpToNotch(completion: completion) }
    }

    func showDone() {
        DispatchQueue.main.async { self._showDone() }
    }

    func dismiss() {
        DispatchQueue.main.async { self._dismiss() }
    }

    /// Height of the notch area (menu bar inset) that the panel extends into.
    private var notchOverlap: CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    private func _showOverlayPanel() {
        let hasNotch = screenHasNotch
        let panelWidth: CGFloat = hasNotch ? max(notchWidth, 120) : 120
        let contentHeight: CGFloat = 32
        // On notch screens, extend the panel up into the menu bar to connect with the notch
        let overlap = hasNotch ? notchOverlap : 0
        let panelHeight = contentHeight + overlap

        if let panel = overlayWindow {
            guard let screen = NSScreen.main else { return }
            let x = panelX(screen, width: panelWidth)
            let y: CGFloat
            if hasNotch {
                y = screen.frame.maxY - panelHeight
            } else {
                y = screen.frame.maxY - panelHeight
            }
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }

        let panel = makeOverlayPanel(width: panelWidth, height: panelHeight)
        panel.hasShadow = false

        let view = RecordingOverlayView(state: overlayState)
        panel.contentView = makeNotchContent(
            width: panelWidth,
            height: panelHeight,
            cornerRadius: hasNotch ? 18 : 12,
            rootView: view.padding(.top, overlap)
        )

        if let screen = NSScreen.main {
            let x = panelX(screen, width: panelWidth)
            let hiddenY = screen.frame.maxY
            let visibleY = screen.frame.maxY - panelHeight

            panel.setFrame(NSRect(x: x, y: hiddenY, width: panelWidth, height: panelHeight), display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()

            // Spring-like drop: overshoots slightly then settles
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
                panel.animator().setFrame(NSRect(x: x, y: visibleY, width: panelWidth, height: panelHeight), display: true)
            }
        }

        self.overlayWindow = panel
    }

    private func _slideUpToNotch(completion: @escaping () -> Void) {
        guard let panel = overlayWindow, let screen = NSScreen.main else {
            completion()
            return
        }

        let hiddenY = screen.frame.maxY
        let frame = panel.frame

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.09
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            panel.animator().setFrame(NSRect(x: frame.origin.x, y: hiddenY, width: frame.width, height: frame.height), display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            self.overlayWindow = nil
            completion()
        })
    }

    private func _showTranscribing() {
        overlayState.phase = .transcribing

        if let panel = overlayWindow {
            panel.orderOut(nil)
            overlayWindow = nil
        }

        if transcribingPanel != nil { return }

        let hasNotch = screenHasNotch
        let contentHeight: CGFloat = 22
        let overlap = hasNotch ? notchOverlap : 0
        let panelWidth: CGFloat = 44
        let panelHeight = contentHeight + overlap

        let panel = makeOverlayPanel(width: panelWidth, height: panelHeight)
        panel.hasShadow = false

        let view = TranscribingIndicatorView()
        panel.contentView = makeNotchContent(
            width: panelWidth,
            height: panelHeight,
            cornerRadius: hasNotch ? 14 : 11,
            rootView: view.padding(.top, overlap)
        )

        if let screen = NSScreen.main {
            let x = panelX(screen, width: panelWidth)
            let y = screen.frame.maxY - panelHeight
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        self.transcribingPanel = panel
    }

    private func _showDone() {
        overlayState.phase = .done

        if let panel = transcribingPanel {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                self.transcribingPanel = nil
            })
        }
    }

    private func _dismiss() {
        if let panel = overlayWindow {
            panel.orderOut(nil)
            overlayWindow = nil
        }
        if let panel = transcribingPanel {
            panel.orderOut(nil)
            transcribingPanel = nil
        }
    }

    private func panelX(_ screen: NSScreen, width: CGFloat) -> CGFloat {
        screen.frame.midX - width / 2
    }
}

// MARK: - Waveform Views

struct WaveformBar: View {
    let amplitude: CGFloat

    private let minHeight: CGFloat = 2
    private let maxHeight: CGFloat = 20

    var body: some View {
        Capsule()
            .fill(JottrTheme.amber)
            .frame(width: 3, height: minHeight + (maxHeight - minHeight) * amplitude)
    }
}

struct WaveformView: View {
    let audioLevel: Float

    private static let barCount = 9
    private static let multipliers: [CGFloat] = [0.35, 0.55, 0.75, 0.9, 1.0, 0.9, 0.75, 0.55, 0.35]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                WaveformBar(amplitude: barAmplitude(for: index))
                    .animation(
                        .interpolatingSpring(stiffness: 600, damping: 28),
                        value: audioLevel
                    )
            }
        }
        .frame(height: 20)
    }

    private func barAmplitude(for index: Int) -> CGFloat {
        let level = CGFloat(audioLevel)
        return min(level * Self.multipliers[index], 1.0)
    }
}

// MARK: - Recording Overlay View

struct InitializingDotsView: View {
    @State private var activeDot = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(JottrTheme.textPrimary.opacity(activeDot == index ? 0.9 : 0.25))
                    .frame(width: 4.5, height: 4.5)
                    .animation(.easeInOut(duration: 0.4), value: activeDot)
            }
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                DispatchQueue.main.async { activeDot = (activeDot + 1) % 3 }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct RecordingOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    @State private var pulsingDotOpacity: Double = 0.5

    var body: some View {
        Group {
            if state.phase == .initializing {
                InitializingDotsView()
                    .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    // Pulsing recording dot
                    Circle()
                        .fill(JottrTheme.amber)
                        .frame(width: 6, height: 6)
                        .opacity(pulsingDotOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                pulsingDotOpacity = 1.0
                            }
                        }

                    // Waveform
                    WaveformView(audioLevel: state.audioLevel)

                    // Intensity badge
                    Text(state.intensityLevel.badgeName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(JottrTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(JottrTheme.amber)
                        )
                        .transition(.opacity)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: state.intensityLevel)
                }
                .padding(.horizontal, 10)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.phase == .initializing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Rectangle()
                .fill(JottrTheme.amber.opacity(state.isIntensityFlashing ? 0.22 : 0.0))
                .animation(.easeOut(duration: 0.35), value: state.isIntensityFlashing)
        )
    }
}

// MARK: - Transcribing Indicator

struct TranscribingIndicatorView: View {
    @State private var animatingDot = 0
    @State private var dotAnimationTimer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(JottrTheme.textPrimary.opacity(animatingDot == index ? 0.9 : 0.25))
                    .frame(width: 4.5, height: 4.5)
                    .animation(.easeInOut(duration: 0.4), value: animatingDot)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startDotAnimation() }
        .onDisappear { stopDotAnimation() }
    }

    private func startDotAnimation() {
        dotAnimationTimer?.invalidate()
        dotAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }

    private func stopDotAnimation() {
        dotAnimationTimer?.invalidate()
        dotAnimationTimer = nil
    }
}
