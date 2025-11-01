import SwiftUI
import AVFoundation
import Accelerate

struct TunerView: View {
    @Binding var isStarted: Bool
    @Binding var sessionMetrics: SessionMetrics
    
    // MARK: - State
    @State private var scale: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme
    @State private var note: String = "A4"
    @State private var frequency: Float = 440.0
    @State private var centOffset: Float = 0.0
    @State private var previousFrequency: Float = 440.0
    @State private var noteHistory: [String] = []
    @State private var confidenceLevel: Float = 0.0
    @State private var showSettings = false
    @State private var referenceToneEnabled = false
    @State private var referenceToneFrequency: Float = 440.0
    @State private var selectedReferenceNote: String = "A4"
    
    // AI-powered insights
    @State private var showInsights = false
    @State private var tuningStabilityScore: Float = 0.0
    @State private var sessionStartTime: Date?
    @State private var accuracyReadings: [Float] = []
    
    // Smoothing factor for frequency to reduce jitter
    private let smoothingFactor: Float = 0.2
    
    // MARK: - Audio processing throttling
    private static var lastProcessingTime: Date = Date.distantPast
    private static let minProcessingInterval: TimeInterval = 1.0 / 30.0 // Max 30 updates per second
    
    // MARK: - Audio
    let audioEngine = AVAudioEngine()
    var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    // Reference tone generation
    private let toneEngine = AVAudioEngine()
    private let tonePlayer = AVAudioPlayerNode()
    
    let referenceNotes = ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4"]
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.7)
    }
    
    init(isStarted: Binding<Bool>, sessionMetrics: Binding<SessionMetrics>) {
        self._isStarted = isStarted
        self._sessionMetrics = sessionMetrics
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 30) {
                // Orb with liquid glass effect
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: orbColors()),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 150 * calculateOrbScale(), height: 150 * calculateOrbScale())
                        .blur(radius: 20)
                        .opacity(0.6)
                    
                    // Main orb with glass effect
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: orbColors().map { $0.opacity(0.7) }),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .frame(width: 150 * calculateOrbScale(), height: 150 * calculateOrbScale())
                        .shadow(color: orbShadowColor(), radius: 30, x: 0, y: 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: frequency)
                    
                    VStack(spacing: 8) {
                        Text(note)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(String(format: "%.1f Hz", frequency))
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Cent offset indicator
                        if isStarted && abs(centOffset) < 50 {
                            Text(centOffsetText())
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(centOffsetColor())
                                .padding(.top, 4)
                        }
                        
                        // Confidence indicator
                        if isStarted {
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { index in
                                    Circle()
                                        .fill(index < Int(confidenceLevel * 5) ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                // Pitch accuracy bar with glass effect
                VStack(spacing: 12) {
                    // Main tuning bar
                    ZStack {
                        // Background track with glass
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.1)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .frame(width: 280, height: 12)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Center marker
                        Rectangle()
                            .fill(primaryTextColor)
                            .frame(width: 3, height: 20)
                        
                        // Tuning indicator with glass effect
                        if isStarted {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(tuningIndicatorColor().opacity(0.8))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                )
                                .frame(width: 20, height: 20)
                                .offset(x: centOffsetToPosition())
                                .shadow(color: tuningIndicatorColor(), radius: 12)
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: centOffset)
                        }
                    }
                    .frame(height: 40)
                    
                    // Accuracy bar with glass effect
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            barColor().opacity(0.8),
                                            barColor().opacity(0.6)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .frame(width: barWidth(geometry: geometry), height: 8)
                        .shadow(color: barColor().opacity(0.4), radius: 8, x: 0, y: 2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: frequency)
                    
                    // Status text with AI insights
                    VStack(spacing: 4) {
                        Text(tuningStatusText())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(tuningStatusColor())
                        
                        if isStarted && accuracyReadings.count > 10 {
                            Text(aiInsightText())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Note history
                if isStarted && !noteHistory.isEmpty {
                    VStack(spacing: 8) {
                        Text("Recent Notes")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                        
                        HStack(spacing: 12) {
                            ForEach(Array(noteHistory.suffix(5).reversed().enumerated()), id: \.element) { index, historicalNote in
                                Text(historicalNote)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(primaryTextColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color.white.opacity(0.5),
                                                                Color.white.opacity(0.2)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            )
                                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: noteHistory.count)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
            
            // Settings button with liquid glass effect - absolutely positioned
            VStack {
                HStack {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                ZStack {
                                    // Liquid glass effect
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.white.opacity(0.6),
                                                            Color.white.opacity(0.2),
                                                            Color.clear
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                }
                            )
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 16)
                .padding(.leading, 16)
                Spacer()
            }
            .offset(y:40)
            
            // AI Insights Banner - Positioned 20px under the start button
            if isStarted && accuracyReadings.count > 5 {
                HStack(spacing: 12) {
                    // Stability indicator
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tuningStabilityScore > 0.7 ? "checkmark.circle.fill" : "waveform.path")
                                .foregroundColor(tuningStabilityScore > 0.7 ? .green : .cyan)
                                .font(.system(size: 14))
                            Text("\(Int(tuningStabilityScore * 100))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }
                        Text("Stability")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.5),
                                                Color.white.opacity(0.2)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Session accuracy
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .foregroundColor(.cyan)
                                .font(.system(size: 14))
                            Text("\(Int(sessionMetrics.averageTuningAccuracy() * 100))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }
                        Text("Accuracy")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.5),
                                                Color.white.opacity(0.2)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Readings count
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.cyan)
                                .font(.system(size: 14))
                            Text("\(sessionMetrics.tuningAccuracyHistory.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                        }
                        Text("Readings")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.5),
                                                Color.white.opacity(0.2)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height - 30)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: accuracyReadings.count)
            }
        }
        .onAppear {
            setupToneEngine()
            // Don't request microphone permission automatically - wait for user interaction
        }
        .sheet(isPresented: $showSettings) {
            tunerSettingsSheet
        }
        .onChange(of: isStarted) { started in
            if started {
                // Request permission when user actually tries to start
                requestMicrophonePermission()
                startAudioEngine()
                if referenceToneEnabled {
                    stopReferenceTone()
                    referenceToneEnabled = false
                }
            } else {
                stopAudioEngine()
                note = "A4"
                frequency = 440.0
                centOffset = 0.0
                noteHistory.removeAll()
                confidenceLevel = 0.0
            }
        }
        .onChange(of: referenceToneEnabled) { enabled in
            if enabled {
                if isStarted {
                    isStarted = false
                }
                playReferenceTone(frequency: referenceToneFrequency)
            } else {
                stopReferenceTone()
            }
        }
        .onChange(of: selectedReferenceNote) { newNote in
            referenceToneFrequency = noteFrequency(note: newNote)
            if referenceToneEnabled {
                stopReferenceTone()
                playReferenceTone(frequency: referenceToneFrequency)
            }
        }
        .onDisappear {
            stopAudioEngine()
            toneEngine.stop()
        }
    }
    
    // MARK: - Settings Sheet
    
    private var tunerSettingsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Reference Tone")) {
                    Toggle("Play Reference Tone", isOn: $referenceToneEnabled)
                        .disabled(isStarted)
                    
                    if referenceToneEnabled || !isStarted {
                        Picker("Note", selection: $selectedReferenceNote) {
                            ForEach(referenceNotes, id: \.self) { note in
                                Text(note).tag(note)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        
                        Text(String(format: "%.1f Hz", referenceToneFrequency))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Tuning Standards")) {
                    Button("A440 (Standard)") {
                        selectedReferenceNote = "A4"
                    }
                    Button("A432 (Alternative)") {
                        referenceToneFrequency = 432.0
                        if referenceToneEnabled {
                            stopReferenceTone()
                            playReferenceTone(frequency: referenceToneFrequency)
                        }
                    }
                    Button("A415 (Baroque)") {
                        referenceToneFrequency = 415.0
                        if referenceToneEnabled {
                            stopReferenceTone()
                            playReferenceTone(frequency: referenceToneFrequency)
                        }
                    }
                }
                
                Section(header: Text("AI Insights")) {
                    HStack {
                        Text("Session Accuracy")
                        Spacer()
                        Text(String(format: "%.0f%%", sessionMetrics.averageTuningAccuracy() * 100))
                            .foregroundColor(sessionMetrics.averageTuningAccuracy() > 0.7 ? .green : .orange)
                    }
                    HStack {
                        Text("Stability Score")
                        Spacer()
                        Text(String(format: "%.0f%%", tuningStabilityScore * 100))
                            .foregroundColor(tuningStabilityScore > 0.7 ? .green : .orange)
                    }
                    HStack {
                        Text("Readings Analyzed")
                        Spacer()
                        Text("\(sessionMetrics.tuningAccuracyHistory.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Frequency Range")
                        Spacer()
                        Text("60-2000 Hz")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Detection Method")
                        Spacer()
                        Text("FFT + Autocorrelation")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Tuner Settings")
            .navigationBarItems(trailing: Button("Done") {
                showSettings = false
            })
        }
    }
    
    // MARK: - UI Helpers
    
    private func orbColors() -> [Color] {
        let accuracy = pitchAccuracy()
        if accuracy > 0.85 {
            return [.green, .mint]
        } else if accuracy > 0.6 {
            return [.yellow, .orange]
        } else {
            return [.red, .orange]
        }
    }
    
    private func orbShadowColor() -> Color {
        let accuracy = pitchAccuracy()
        if accuracy > 0.85 {
            return .green.opacity(0.6)
        } else if accuracy > 0.6 {
            return .yellow.opacity(0.6)
        } else {
            return .red.opacity(0.6)
        }
    }
    
    private func centOffsetText() -> String {
        let cents = Int(round(centOffset))
        if cents > 0 {
            return "+\(cents)¢"
        } else if cents < 0 {
            return "\(cents)¢"
        } else {
            return "In Tune!"
        }
    }
    
    private func centOffsetColor() -> Color {
        if abs(centOffset) < 5 {
            return .green
        } else if abs(centOffset) < 15 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    private func tuningStatusText() -> String {
        if !isStarted {
            return "Tap Start to Begin"
        }
        
        let accuracy = pitchAccuracy()
        if accuracy > 0.85 {
            return "Perfect!"
        } else if accuracy > 0.6 {
            return "Close"
        } else if frequency < 60 {
            return "Play a note"
        } else {
            return "Keep tuning"
        }
    }
    
    private func aiInsightText() -> String {
        let avgAccuracy = sessionMetrics.averageTuningAccuracy()
        
        if tuningStabilityScore > 0.8 {
            return "🎯 Excellent stability!"
        } else if tuningStabilityScore > 0.6 {
            return "📊 Good consistency"
        } else if avgAccuracy > 0.7 {
            return "💡 Try holding notes longer"
        } else {
            return "🎵 Keep practicing"
        }
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }
    
    private func tuningStatusColor() -> Color {
        let accuracy = pitchAccuracy()
        if accuracy > 0.85 {
            return .green
        } else if accuracy > 0.6 {
            return .yellow
        } else {
            return .secondary
        }
    }
    
    private func tuningIndicatorColor() -> Color {
        if abs(centOffset) < 5 {
            return .green
        } else if abs(centOffset) < 15 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func centOffsetToPosition() -> CGFloat {
        // Map cents (-50 to +50) to position (-130 to +130)
        let clampedCents = max(-50, min(50, centOffset))
        return CGFloat(clampedCents) * 2.6
    }
    
    // MARK: - Bar visuals
    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let maxWidth: CGFloat = 250
        let accuracy = pitchAccuracy()
        return maxWidth * CGFloat(accuracy)
    }
    
    private func barColor() -> Color {
        let accuracy = pitchAccuracy()
        return Color(red: Double(1 - accuracy),
                     green: Double(accuracy),
                     blue: 0)
    }
    
    // MARK: - Pitch accuracy (0–1)
    private func pitchAccuracy() -> Float {
        let targetFreq = noteFrequency(note: note)
        guard targetFreq > 0 else { return 0 }
        let diff = abs(frequency - targetFreq)
        let maxDiff: Float = 20 // Reduced from 25 for more responsive accuracy detection
        let clamped = max(0, 1 - diff / maxDiff)
        return clamped
    }
    
    private func calculateOrbScale() -> CGFloat {
        let accuracy = pitchAccuracy()
        return CGFloat(1 + accuracy * 0.5) // orb grows up to 1.5x
    }
    
    // Convert note name to frequency
    private func noteFrequency(note: String) -> Float {
        let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let pattern = "([A-G]#?)(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let matches = regex.matches(in: note, range: NSRange(note.startIndex..., in: note))
        guard let match = matches.first,
              let noteRange = Range(match.range(at: 1), in: note),
              let octaveRange = Range(match.range(at: 2), in: note) else { return 0 }
        
        let name = String(note[noteRange])
        let octave = Int(note[octaveRange]) ?? 4
        guard let index = noteNames.firstIndex(of: name) else { return 0 }
        return 440 * pow(2, Float(index - 9)/12 + Float(octave - 4))
    }
    
    // MARK: - Microphone Permission
    func requestMicrophonePermission() {
        // Check if we already have permission
        let audioSession = AVAudioSession.sharedInstance()
        
        if #available(iOS 17.0, *) {
            switch audioSession.recordPermission {
            case .granted:
                setupAudioSession()
            case .denied:
                print("Microphone access denied by user")
                // Could show alert here
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setupAudioSession()
                        }
                    } else {
                        print("Microphone permission denied")
                    }
                }
            @unknown default:
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setupAudioSession()
                        }
                    } else {
                        print("Microphone permission denied")
                    }
                }
            }
        } else {
            switch audioSession.recordPermission {
            case .granted:
                setupAudioSession()
            case .denied:
                print("Microphone access denied by user")
            case .undetermined:
                audioSession.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setupAudioSession()
                        }
                    } else {
                        print("Microphone permission denied")
                    }
                }
            @unknown default:
                audioSession.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setupAudioSession()
                        }
                    } else {
                        print("Microphone permission denied")
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Session
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("Audio session setup successful")
        } catch {
            print("Failed to set up audio session:", error)
            // Don't crash - show user-friendly error instead
            DispatchQueue.main.async {
                // You could show an alert here
                print("Audio session error - this might cause issues with microphone access")
            }
        }
    }
    
    // MARK: - Start Audio Engine
    func startAudioEngine() {
        guard !audioEngine.isRunning else { return }

        do {
            // Create and attach mixer node with volume 0 to prevent feedback
            let mixer = AVAudioMixerNode()
            mixer.volume = 0
            audioEngine.attach(mixer)

            let inputFormat = inputNode.outputFormat(forBus: 0)
            audioEngine.connect(inputNode, to: mixer, format: inputFormat)

            // Convert to mono Float32 format for better FFT processing
            let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                           sampleRate: inputFormat.sampleRate,
                                           channels: 1,
                                           interleaved: false)
            audioEngine.connect(mixer, to: audioEngine.mainMixerNode, format: mixerFormat)

            // Use buffer size that's a power of 2 for FFT
            let bufferSize: AVAudioFrameCount = 2048

            mixer.installTap(onBus: 0, bufferSize: bufferSize, format: mixerFormat) { [self] buffer, _ in
                guard let samples = buffer.floatChannelData?[0] else { return }
                let frameCount = Int(buffer.frameLength)

                // Throttle processing to prevent overload
                let now = Date()
                guard now.timeIntervalSince(TunerView.lastProcessingTime) >= TunerView.minProcessingInterval else { return }
                TunerView.lastProcessingTime = now

                let detectedFrequency = self.performPitchDetection(samples: samples, frameCount: frameCount, sampleRate: Float(mixerFormat!.sampleRate))

                DispatchQueue.main.async {
                    // Only update if we have a valid frequency (above 60 Hz, below 2000 Hz)
                    if detectedFrequency >= 60 && detectedFrequency <= 2000 {
                        // Use more responsive smoothing for faster updates
                        let smoothingFactor: Float = 0.3  // Increased from 0.2 for more responsive updates
                        self.frequency = self.previousFrequency * (1 - smoothingFactor) + detectedFrequency * smoothingFactor
                        self.previousFrequency = self.frequency

                        // Calculate note and cent offset
                        let result = self.calculateNoteAndCents(from: self.frequency)
                        let newNote = result.note
                        self.centOffset = result.cents

                        // Update note history when note changes
                        if newNote != self.note {
                            self.note = newNote
                            if !self.noteHistory.contains(newNote) || self.noteHistory.last != newNote {
                                self.noteHistory.append(newNote)
                                if self.noteHistory.count > 10 {
                                    self.noteHistory.removeFirst()
                                }
                            }
                        }

                        // Update confidence based on pitch accuracy
                        let accuracy = self.pitchAccuracy()
                        self.confidenceLevel = accuracy

                        // AI: Record accuracy for analysis
                        self.accuracyReadings.append(accuracy)
                        if self.accuracyReadings.count > 50 {
                            self.accuracyReadings.removeFirst()
                        }
                        self.sessionMetrics.recordTuningAccuracy(accuracy)

                        // Calculate stability score
                        if self.accuracyReadings.count >= 10 {
                            let recent = Array(self.accuracyReadings.suffix(10))
                            let variance = self.calculateVariance(recent)
                            self.tuningStabilityScore = max(0, 1 - variance)
                        }
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            print("Started Audio Engine successfully")
        } catch {
            print("Error starting Audio Engine:", error)
            // Don't crash - handle gracefully
            DispatchQueue.main.async {
                print("Audio engine failed to start - microphone may not be available")
            }
        }
    }
    
    // MARK: - Stop Audio Engine
    func stopAudioEngine() {
        guard audioEngine.isRunning else { return }

        // Remove tap from all attached nodes
        for node in audioEngine.attachedNodes {
            if let mixerNode = node as? AVAudioMixerNode {
                mixerNode.removeTap(onBus: 0)
            }
        }

        audioEngine.stop()
        audioEngine.reset()
        print("Stopped Audio Engine")
    }
    
    // MARK: - ENHANCED: FFT Pitch Detection with Autocorrelation Fallback
    func performPitchDetection(samples: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> Float {
        // Calculate RMS to determine signal strength
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
        
        // Dynamic threshold based on signal strength
        let signalThreshold: Float = 0.01
        guard rms > signalThreshold else { return 0 }
        
        // Try FFT-based detection first
        let fftFrequency = performFFTDetection(samples: samples, frameCount: frameCount, sampleRate: sampleRate, rms: rms)
        
        // For low frequencies or weak signals, use autocorrelation as fallback
        if fftFrequency < 100 || rms < 0.05 {
            let acfFrequency = performAutocorrelation(samples: samples, frameCount: frameCount, sampleRate: sampleRate)
            if acfFrequency > 0 {
                return acfFrequency
            }
        }
        
        return fftFrequency
    }
    
    // MARK: - FFT-based Detection (Fixed implementation)
    private func performFFTDetection(samples: UnsafePointer<Float>, frameCount: Int, sampleRate: Float, rms: Float) -> Float {
        let log2n = vDSP_Length(log2(Float(frameCount)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return 0 }

        defer {
            vDSP_destroy_fftsetup(fftSetup)
        }

        // Copy data into real part and apply Hanning window
        var realParts = [Float](repeating: 0.0, count: frameCount)
        var imagParts = [Float](repeating: 0.0, count: frameCount)

        for i in 0..<frameCount {
            realParts[i] = samples[i]
        }

        // Apply Hanning window to reduce spectral leakage
        var hanningWindow = [Float](repeating: 0.0, count: frameCount)
        vDSP_hann_window(&hanningWindow, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realParts, 1, hanningWindow, 1, &realParts, 1, vDSP_Length(frameCount))

        // Initialize imaginary part to zero
        vDSP_vclr(&imagParts, 1, vDSP_Length(frameCount))

        // Use withUnsafeMutableBufferPointer to ensure pointer lifetime
        return realParts.withUnsafeMutableBufferPointer { realPtr in
            imagParts.withUnsafeMutableBufferPointer { imagPtr in
                // Create DSP Split Complex with safe pointers
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                // Perform FFT
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Compute magnitude spectrum (only take first N/2 bins)
                var magnitudes = [Float](repeating: 0.0, count: frameCount / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount / 2))

                // Find peak in relevant frequency range
                let frequencyResolution = sampleRate / Float(frameCount)
                let minIndex = max(1, Int(50.0 / frequencyResolution))  // Lower minimum frequency
                let maxIndex = min(Int(2200.0 / frequencyResolution), frameCount/2 - 1)  // Higher maximum frequency

                var maxMagnitude: Float = 0
                var maxPeakIndex: vDSP_Length = 0

                if maxIndex > minIndex {
                    let searchRange = maxIndex - minIndex
                    magnitudes.withUnsafeBufferPointer { buffer in
                        let offsetPointer = buffer.baseAddress! + minIndex
                        vDSP_maxvi(offsetPointer, 1, &maxMagnitude, &maxPeakIndex, vDSP_Length(searchRange))
                    }
                    maxPeakIndex += vDSP_Length(minIndex)
                }

                // More sensitive magnitude threshold
                let magnitudeThreshold = rms * rms * Float(frameCount) * 0.05
                guard maxMagnitude > magnitudeThreshold, maxPeakIndex > 0, maxPeakIndex < frameCount/2 - 1 else {
                    return 0
                }

                // Use quadratic interpolation for better accuracy
                let y1 = magnitudes[Int(maxPeakIndex) - 1]
                let y2 = magnitudes[Int(maxPeakIndex)]
                let y3 = magnitudes[Int(maxPeakIndex) + 1]

                // Quadratic interpolation formula
                let delta = 0.5 * (y1 - y3) / (y1 - 2 * y2 + y3)
                let interpolatedIndex = Float(maxPeakIndex) + delta

                return interpolatedIndex * frequencyResolution
            }
        }
    }
    
    // MARK: - Autocorrelation-based Detection (Better for low frequencies, optimized)
    private func performAutocorrelation(samples: UnsafePointer<Float>, frameCount: Int, sampleRate: Float) -> Float {
        // Use smaller correlation array for memory efficiency
        let maxLags = min(frameCount / 4, 2048) // Limit correlation length
        var correlation = [Float](repeating: 0, count: maxLags)
        
        // Compute autocorrelation with optimized algorithm for first part
        let computeLags = min(maxLags, frameCount / 2)
        for lag in 0..<computeLags {
            var sum: Float = 0
            let maxI = min(frameCount - lag, frameCount / 2) // Limit computation
            for i in 0..<maxI {
                sum += samples[i] * samples[i + lag]
            }
            correlation[lag] = sum
        }
        
        // OPTIMIZED: Find first peak after initial peak (lag 0) with better sensitivity
        let minLag = Int(sampleRate / 2200) // Max 2200 Hz for better high frequency detection
        let maxLag = Int(sampleRate / 50)   // Min 50 Hz for better low frequency detection
        
        var maxCorr: Float = 0
        var bestLag = 0
        
        for lag in minLag..<min(maxLag, computeLags) {
            if correlation[lag] > maxCorr {
                maxCorr = correlation[lag]
                bestLag = lag
            }
        }
        
        // OPTIMIZED: Lower threshold for more sensitive detection
        guard bestLag > 0, maxCorr > correlation[0] * 0.2 else { return 0 }  // Reduced from 0.3
        
        return sampleRate / Float(bestLag)
    }
    
    // MARK: - Reference Tone Generation
    
    private func setupToneEngine() {
        toneEngine.attach(tonePlayer)
        toneEngine.connect(tonePlayer, to: toneEngine.mainMixerNode, format: nil)
        
        do {
            try toneEngine.start()
        } catch {
            print("Failed to start tone engine: \(error)")
        }
    }
    
    private func playReferenceTone(frequency: Float) {
        let sampleRate = 44100.0
        let duration = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // Get the tonePlayer's output format (non-optional)
        let playerFormat = tonePlayer.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playerFormat, frameCapacity: frameCount) else { return }
        
        buffer.frameLength = frameCount
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(playerFormat.channelCount))
        let floats = UnsafeMutableBufferPointer<Float>(start: channels[0], count: Int(frameCount))
        
        // Generate sine wave
        let amplitude: Float = 0.3
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            floats[i] = amplitude * sin(2.0 * Float.pi * frequency * time)
        }
        
        tonePlayer.stop()
        tonePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        tonePlayer.play()
    }
    
    private func stopReferenceTone() {
        tonePlayer.stop()
    }
    
    // MARK: - Calculate Note and Cent Offset from Frequency
    func calculateNoteAndCents(from frequency: Float) -> (note: String, cents: Float) {
        guard frequency > 0 else { return ("-", 0) }
        
        // Calculate MIDI note number (A4 = 440 Hz = MIDI 69)
        let midiNoteFloat = 12 * log2(Double(frequency) / 440.0) + 69
        let midiNote = Int(round(midiNoteFloat))
        
        // Calculate cent offset from the nearest note
        let centOffset = Float((midiNoteFloat - Double(midiNote)) * 100)
        
        let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let noteName = noteNames[midiNote % 12]
        let octave = midiNote / 12 - 1
        
        return ("\(noteName)\(octave)", centOffset)
    }
}

struct TunerView_Previews: PreviewProvider {
    static var previews: some View {
        TunerView(isStarted: .constant(false), sessionMetrics: .constant(SessionMetrics()))
    }
}
