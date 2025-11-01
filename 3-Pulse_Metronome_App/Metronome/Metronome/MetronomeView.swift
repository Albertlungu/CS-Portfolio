import SwiftUI
import Combine
import CoreHaptics
import AVFoundation

struct MetronomeView: View {
    
    @Binding var isStarted: Bool
    @Binding var sessionMetrics: SessionMetrics
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false
    
    @State private var dragOffsetRight: CGFloat = 0
    @State private var currentOffsetRight: CGFloat = 0
    @State private var isDraggingRight = false
    @State private var dragStartYRight: CGFloat = 0
    
    @State private var dragOffsetLeft: CGFloat = 0
    @State private var currentOffsetLeft: CGFloat = 0
    @State private var isDraggingLeft = false
    @State private var dragStartYLeft: CGFloat = 0
    
    @State private var bpm: Int = 120
    @State private var timeSignatureIndex: Int = 0
    @State private var beatCounter: Int = 0
    
    // Audio player pool for reliable playback at high tempos
    @State private var highBeatPlayers: [AVAudioPlayer] = []
    @State private var lowBeatPlayers: [AVAudioPlayer] = []
    @State private var currentHighPlayerIndex: Int = 0
    @State private var currentLowPlayerIndex: Int = 0
    private let playerPoolSize = 2  // Reduced from 4 for lower memory usage
    
    @State private var showSettings = false
    @State private var accentFirstBeat = true
    @State private var hapticFeedback = true
    @State private var visualFeedback = true
    @State private var soundVolume: Float = 1.0
    @State private var subdivision: Int = 0 // 0=none, 1=eighth, 2=triplet, 3=sixteenth
    @State private var subdivisionCounter: Int = 0
    @State private var bpmHistory: [Int] = []
    
    let leftDotPositions: [CGFloat] = (0..<10).map { CGFloat($0) * (240 / 9) }.reversed()
    let rightDotPositions: [CGFloat] = (0..<8).map { CGFloat($0) * (240 / 7) }.reversed()
    let timeSignatures = ["4/4", "2/4", "3/4", "6/4", "2/2", "3/2", "4/2", "6/8", "9/8", "12/8"]
    
    @State private var hapticEngine: CHHapticEngine?
    @State private var metronomeTimer: Timer?
    private let audioQueue = DispatchQueue(label: "com.metronome.audio", qos: .userInteractive)
    
    @State private var highlightedDot: Int? = nil
    @State private var tapTimes: [Date] = []
    @State private var showTapInfo = false
    
    // AI-powered practice insights
    @State private var practiceStartTime: Date?
    @State private var tempoConsistency: Float = 0.0
    @State private var suggestedNextTempo: Int?
    @State private var sessionTimer: Timer?
    @State private var currentSessionDuration: TimeInterval = 0
    
    var beatInterval: TimeInterval {
        60.0 / Double(bpm)
    }
    
    var currentTopNumber: Int {
        Int(timeSignatures[timeSignatureIndex].split(separator: "/")[0]) ?? 4
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundOverlay
                
                VStack(spacing: 0) {
                    topInfoBar
                    
                    mainCircle
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                
                rightSlider(in: geometry)
                leftSlider(in: geometry)
                
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
                .offset(y: 40)
                
                // AI Practice Stats Banner - Positioned 20px under the start button
                if isStarted && sessionMetrics.tempoChanges.count > 3 {
                    aiStatsBanner
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 30)
                }
            }
            .onAppear {
                prepareAudioSession()
                prepareHaptic()
                loadSounds()
                // Initialize BPM slider position
                let percentage = (Double(bpm) - 40) / (240 - 40)
                dragOffsetRight = CGFloat(percentage * 275)
                currentOffsetRight = dragOffsetRight
            }
            .onChange(of: isStarted) { started in
                if started {
                    beatCounter = 0
                    updateTimer()
                    showTapInfo = false
                    practiceStartTime = Date()
                    currentSessionDuration = 0
                    // Start session timer for live updates
                    sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        if let startTime = practiceStartTime {
                            currentSessionDuration = Date().timeIntervalSince(startTime)
                        }
                    }
                } else {
                    metronomeTimer?.invalidate()
                    sessionTimer?.invalidate()
                    sessionTimer = nil
                    pulse = false
                    highlightedDot = nil
                    if let startTime = practiceStartTime {
                        let sessionDuration = Date().timeIntervalSince(startTime)
                        sessionMetrics.metronomeTotalTime += sessionDuration
                    }
                    practiceStartTime = nil
                    currentSessionDuration = 0
                }
            }
            .onChange(of: bpm) { newBPM in
                updateTimer()
                sessionMetrics.recordTempo(newBPM)
                calculateTempoConsistency()
                suggestNextTempo()
            }
            .onChange(of: timeSignatureIndex) { _ in
                beatCounter = 0
            }
            .onChange(of: soundVolume) { newVolume in
                for player in highBeatPlayers {
                    player.volume = newVolume
                }
                for player in lowBeatPlayers {
                    player.volume = newVolume
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
        }
        .onDisappear {
            cleanupAudioPlayers()
            metronomeTimer?.invalidate()
            sessionTimer?.invalidate()
            hapticEngine?.stop()
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundOverlay: some View {
        Color.black.opacity(isDraggingLeft || isDraggingRight ? 0.3 : 0.0)
            .ignoresSafeArea()
            .animation(.easeInOut, value: isDraggingLeft || isDraggingRight)
    }
    
    private var topInfoBar: some View {
        HStack {
            Spacer()
                .frame(width: 60) // Reserve space for absolutely positioned button
            
            Spacer()
            
            if showTapInfo {
                Text("Tap circle 4+ times to set tempo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Beat \(beatCounter % currentTopNumber + 1)/\(currentTopNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                Text(String(format: "%.1f sec", beatInterval))
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.5))
                if subdivision > 0 {
                    Text(subdivisionName())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            .padding()
            .opacity(isStarted ? 1 : 0)
        }
        .padding(.top, 40)
    }
    
    private var aiStatsBanner: some View {
        HStack(spacing: 12) {
            // Practice duration
            statsCard(
                icon: "clock.fill",
                iconColor: .cyan,
                value: formatDuration(currentSessionDuration),
                label: "Session"
            )
            
            // Tempo changes
            statsCard(
                icon: tempoTrendIcon(),
                iconColor: tempoTrendColor(),
                value: "\(sessionMetrics.tempoChanges.count)",
                label: "Changes"
            )
            
            // Suggested tempo (if available)
            if let nextTempo = suggestedNextTempo {
                suggestedTempoCard(nextTempo: nextTempo)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: sessionMetrics.tempoChanges.count)
    }
    
    private func statsCard(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .animation(.none, value: value)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.7))
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
    
    private func suggestedTempoCard(nextTempo: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("\(nextTempo)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("Next BPM")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.7))
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
                                    Color.green.opacity(0.5),
                                    Color.green.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.green.opacity(0.2), radius: 8, x: 0, y: 2)
        )
        .onTapGesture {
            bpm = nextTempo
            updateSliderPosition()
        }
    }
    
    private var settingsButton: some View {
        VStack {
            HStack {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(
                            ZStack {
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
            Spacer()
        }
    }
    
    private var mainCircle: some View {
        ZStack {
            // Outer ring for visual feedback
            if visualFeedback && isStarted {
                visualFeedbackRing
            }
            
            // Main circle with liquid glass effect
            glassCircle
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulse)
                .onTapGesture {
                    registerTap()
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showTapInfo.toggle()
                }
            
            // Beat indicators around circle with glass effect
            beatIndicators
            
            // Subdivision indicators (inner circle) with glass effect
            if subdivision > 0 && isStarted {
                subdivisionIndicators
            }
            
            // BPM display in center
            bpmDisplay
        }
        .offset(y: -100)
    }
    
    private var visualFeedbackRing: some View {
        Circle()
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.3), .indigo.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: pulse ? 4 : 2
            )
            .frame(width: 200, height: 200)
            .scaleEffect(pulse ? 1.1 : 1.0)
            .opacity(pulse ? 0.8 : 0.4)
            .animation(.easeOut(duration: beatInterval / 2), value: pulse)
    }
    
    private var glassCircle: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.indigo, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 120, height: 120)
                .blur(radius: 15)
                .opacity(0.7)
            
            // Glass circle
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.indigo.opacity(0.7), .blue.opacity(0.7)]),
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
                .frame(width: 120, height: 120)
                .shadow(color: .blue.opacity(0.5), radius: pulse ? 50 : 10, x: 0, y: pulse ? 10 : 5)
        }
    }
    
    private var beatIndicators: some View {
        ForEach(0..<currentTopNumber, id: \.self) { i in
            let angle = Double(i) / Double(currentTopNumber) * 2 * Double.pi - Double.pi / 2
            let baseRadius: CGFloat = 80
            let scale: CGFloat = pulse ? 1.2 : 1.0
            let animatedRadius = baseRadius * scale
            let x = CGFloat(cos(angle)) * animatedRadius
            let y = CGFloat(sin(angle)) * animatedRadius
            let dotColor = highlightedDot == i ? Color.yellow : (i == 0 && accentFirstBeat ? Color.red : Color.white)
            
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(dotColor.opacity(0.8))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: highlightedDot == i ? 2 : 1)
                )
                .frame(width: highlightedDot == i ? 14 : 8, height: highlightedDot == i ? 14 : 8)
                .offset(x: x, y: y)
                .shadow(color: highlightedDot == i ? dotColor.opacity(0.8) : .clear, radius: highlightedDot == i ? 8 : 2)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: highlightedDot)
        }
    }
    
    private var subdivisionIndicators: some View {
        let subdivCount = subdivisionCount()
        return ForEach(0..<subdivCount, id: \.self) { i in
            let angle = Double(i) / Double(subdivCount) * 2 * Double.pi - Double.pi / 2
            let radius: CGFloat = 50
            let x = CGFloat(cos(angle)) * radius
            let y = CGFloat(sin(angle)) * radius
            let isActive = subdivisionCounter % subdivCount == i
            
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(isActive ? Color.cyan.opacity(0.8) : Color.white.opacity(0.3))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.8 : 0.3), lineWidth: 1)
                )
                .frame(width: isActive ? 7 : 4, height: isActive ? 7 : 4)
                .offset(x: x, y: y)
                .shadow(color: isActive ? Color.cyan.opacity(0.6) : .clear, radius: isActive ? 4 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: subdivisionCounter)
        }
    }
    
    private var bpmDisplay: some View {
        VStack(spacing: 4) {
            Text("\(bpm)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("BPM")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.8))
        }
    }
    
    private func rightSlider(in geometry: GeometryProxy) -> some View {
        VStack {
            ZStack {
                let sliderHeight: CGFloat = 275
                let safeInset: CGFloat = 12
                let trackX = geometry.size.width - 28
                
                // Slider track with glass effect
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: isDraggingRight ? 38 : 28, height: sliderHeight)
                    .overlay(
                        VStack(spacing: 0) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.blue.opacity(0.8), .indigo.opacity(0.8)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                                .frame(height: dragOffsetRight)
                        }
                    )
                    .position(x: trackX, y: geometry.size.height / 2)
                    .shadow(color: isDraggingRight ? Color.blue.opacity(0.5) : Color.black.opacity(0.1), radius: isDraggingRight ? 15 : 5, x: 0, y: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingRight)
                
                // Tempo markings
                ForEach(0..<8, id: \.self) { index in
                    let yBase = geometry.size.height / 2 - (sliderHeight/2 - safeInset) + rightDotPositions[index]
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        Text(tempoMarkLabel(for: index))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: -34)
                    }
                    .position(x: trackX, y: yBase)
                    .opacity(isDraggingRight ? 1 : 0)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let sliderHeight: CGFloat = 275
                        if dragStartYRight == 0 { dragStartYRight = value.startLocation.y }
                        let delta = dragStartYRight - value.location.y
                        dragOffsetRight = max(0, min(sliderHeight, currentOffsetRight + delta))
                        let percentage = dragOffsetRight / sliderHeight
                        bpm = Int(40 + percentage * (240 - 40))
                    }
                    .onEnded { _ in
                        dragStartYRight = 0
                        currentOffsetRight = dragOffsetRight
                        withAnimation { isDraggingRight = false }
                    }
            )
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onChanged { _ in withAnimation { isDraggingRight = true } }
                    .onEnded { _ in withAnimation { isDraggingRight = false } }
            )
            
            // BPM labels positioned relative to slider
            VStack(spacing: 4) {
                Text("\(bpm)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("BPM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                Text(tempoDescription())
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            // Position 20px below the slider bottom
            .position(x: geometry.size.width / 2 - 5, y: geometry.size.height / 2 - 270)
        }
        .offset(y: -50)
    }
    
    private func leftSlider(in geometry: GeometryProxy) -> some View {
        VStack {
            ZStack {
                let sliderHeight: CGFloat = 275
                let safeInset: CGFloat = 12
                let trackX: CGFloat = 28
                
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: isDraggingLeft ? 38 : 28, height: sliderHeight)
                    .overlay(
                        VStack(spacing: 0) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.blue.opacity(0.8), .indigo.opacity(0.8)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                                .frame(height: dragOffsetLeft)
                        }
                    )
                    .position(x: trackX, y: geometry.size.height / 2)
                    .shadow(color: isDraggingLeft ? Color.blue.opacity(0.5) : Color.black.opacity(0.1), radius: isDraggingLeft ? 15 : 5, x: 0, y: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingLeft)
                
                ForEach(0..<10, id: \.self) { index in
                    let yBase = geometry.size.height / 2 - (sliderHeight/2 - safeInset) + leftDotPositions[index]
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        Text(timeSignatures[index])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .offset(x: 34)
                    }
                    .position(x: trackX, y: yBase)
                    .opacity(isDraggingLeft ? 1 : 0)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let sliderHeight: CGFloat = 275
                        if dragStartYLeft == 0 { dragStartYLeft = value.startLocation.y }
                        let delta = dragStartYLeft - value.location.y
                        dragOffsetLeft = max(0, min(sliderHeight, currentOffsetLeft + delta))
                        
                        let nearestIndex = leftDotPositions.enumerated().min(by: {
                            abs($0.element - dragOffsetLeft) < abs($1.element - dragOffsetLeft)
                        })?.offset ?? 0
                        timeSignatureIndex = nearestIndex
                    }
                    .onEnded { _ in
                        dragStartYLeft = 0
                        let nearestIndex = leftDotPositions.enumerated().min(by: {
                            abs($0.element - dragOffsetLeft) < abs($1.element - dragOffsetLeft)
                        })?.offset ?? 0
                        timeSignatureIndex = nearestIndex
                        let nearest = leftDotPositions[nearestIndex]
                        withAnimation(.interpolatingSpring(stiffness: 120, damping: 10)) {
                            dragOffsetLeft = nearest
                            currentOffsetLeft = nearest
                        }
                        withAnimation { isDraggingLeft = false }
                    }
            )
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onChanged { _ in withAnimation { isDraggingLeft = true } }
                    .onEnded { _ in withAnimation { isDraggingLeft = false } }
            )
            
            // Time signature label positioned relative to slider
            Text(timeSignatures[timeSignatureIndex])
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                // Position 20px below the slider bottom
                .position(x: geometry.size.width / 2 + 5, y: geometry.size.height / 2 - 285)
        }
        .offset(y: -50)
    }
    
    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Audio Settings")) {
                    Toggle("Accent First Beat", isOn: $accentFirstBeat)
                    
                    VStack(alignment: .leading) {
                        Text("Volume")
                        Slider(value: $soundVolume, in: 0...1)
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
                
                Section(header: Text("Feedback")) {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    Toggle("Visual Pulse", isOn: $visualFeedback)
                }
                
                Section(header: Text("Subdivisions")) {
                    Picker("Subdivision", selection: $subdivision) {
                        Text("None").tag(0)
                        Text("Eighth Notes").tag(1)
                        Text("Triplets").tag(2)
                        Text("Sixteenth Notes").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Quick Presets")) {
                    Button("Largo (40-60 BPM)") {
                        bpm = 50
                        updateSliderPosition()
                    }
                    Button("Andante (76-108 BPM)") {
                        bpm = 92
                        updateSliderPosition()
                    }
                    Button("Moderato (108-120 BPM)") {
                        bpm = 114
                        updateSliderPosition()
                    }
                    Button("Allegro (120-168 BPM)") {
                        bpm = 144
                        updateSliderPosition()
                    }
                    Button("Presto (168-200 BPM)") {
                        bpm = 184
                        updateSliderPosition()
                    }
                }
                
                Section(header: Text("AI Practice Insights")) {
                    HStack {
                        Text("Session Duration")
                        Spacer()
                        Text(formatDuration(sessionMetrics.metronomeTotalTime))
                            .foregroundColor(.cyan)
                    }
                    
                    if let nextTempo = suggestedNextTempo {
                        HStack {
                            Text("Suggested Next")
                            Spacer()
                            Button("\(nextTempo) BPM →") {
                                bpm = nextTempo
                                updateSliderPosition()
                                showSettings = false
                            }
                            .foregroundColor(.green)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tempo Trend")
                        Text(sessionMetrics.tempoTrend())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("BPM History")) {
                    if bpmHistory.isEmpty {
                        Text("No history yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bpmHistory.suffix(5).reversed(), id: \.self) { historicalBPM in
                            HStack {
                                Text("\(historicalBPM) BPM")
                                Spacer()
                                Button("Use") {
                                    bpm = historicalBPM
                                    updateSliderPosition()
                                    showSettings = false
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Tempo Range")
                        Spacer()
                        Text("40-240 BPM")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Time Signatures")
                        Spacer()
                        Text("\(timeSignatures.count) options")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                showSettings = false
            })
        }
    }
    
    // MARK: - Helper Functions
    
    private func subdivisionName() -> String {
        switch subdivision {
        case 1: return "♪ Eighths"
        case 2: return "♪♪♪ Triplets"
        case 3: return "♬ Sixteenths"
        default: return ""
        }
    }
    
    private func subdivisionMultiplier() -> Int {
        switch subdivision {
        case 1: return 2  // Eighth notes
        case 2: return 3  // Triplets
        case 3: return 4  // Sixteenth notes
        default: return 1
        }
    }
    
    private func subdivisionCount() -> Int {
        return currentTopNumber * subdivisionMultiplier()
    }
    
    private func tempoMarkLabel(for index: Int) -> String {
        let bpmValues = [40, 70, 100, 130, 160, 190, 220, 240]
        return "\(bpmValues[index])"
    }
    
    private func tempoDescription() -> String {
        switch bpm {
        case 0..<60: return "Largo"
        case 60..<76: return "Adagio"
        case 76..<108: return "Andante"
        case 108..<120: return "Moderato"
        case 120..<168: return "Allegro"
        case 168..<200: return "Presto"
        default: return "Prestissimo"
        }
    }
    
    private func updateSliderPosition() {
        let percentage = (Double(bpm) - 40) / (240 - 40)
        withAnimation {
            dragOffsetRight = CGFloat(percentage * 275)
            currentOffsetRight = dragOffsetRight
        }
    }
    
    // MARK: - Timer and Playback Functions
    
    private func updateTimer() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        guard isStarted else { return }
        pulse = false
        subdivisionCounter = 0
        
        let interval = subdivision > 0 ? beatInterval / Double(subdivisionMultiplier()) : beatInterval
        
        // Use direct Timer for better precision at high tempos
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] _ in
            if subdivision > 0 {
                // Handle subdivisions
                let isMainBeat = subdivisionCounter % subdivisionMultiplier() == 0
                if isMainBeat {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: min(0.1, beatInterval / 4))) {
                            pulse.toggle()
                            highlightedDot = beatCounter % currentTopNumber
                        }
                    }
                    let isFirstBeat = beatCounter % currentTopNumber == 0
                    playSound(beat: isFirstBeat && accentFirstBeat)
                    
                    // Skip haptics at very high tempos to avoid lag
                    if hapticFeedback && bpm < 180 {
                        DispatchQueue.main.async {
                            triggerHapticFeedback(strong: isFirstBeat && accentFirstBeat)
                        }
                    }
                    beatCounter += 1
                } else {
                    // Subdivision tick (lighter sound/haptic)
                    playSound(beat: false)
                    if hapticFeedback && bpm < 180 {
                        DispatchQueue.main.async {
                            triggerHapticFeedback(strong: false)
                        }
                    }
                }
                subdivisionCounter += 1
            } else {
                // Normal beat without subdivisions
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: min(0.1, beatInterval / 4))) {
                        pulse.toggle()
                        highlightedDot = beatCounter % currentTopNumber
                    }
                }
                let isFirstBeat = beatCounter % currentTopNumber == 0
                playSound(beat: isFirstBeat && accentFirstBeat)
                
                // Skip haptics at very high tempos to avoid lag
                if hapticFeedback && bpm < 180 {
                    DispatchQueue.main.async {
                        triggerHapticFeedback(strong: isFirstBeat && accentFirstBeat)
                    }
                }
                beatCounter += 1
            }
        }
        
        // Ensure timer runs even during UI interactions
        if let timer = metronomeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func playSound(beat: Bool) {
        // Use audio queue for reliable playback without blocking
        audioQueue.async { [self] in
            if beat {
                // Use next player from pool
                if !highBeatPlayers.isEmpty {
                    let player = highBeatPlayers[currentHighPlayerIndex]
                    player.stop()
                    player.currentTime = 0
                    player.play()
                    currentHighPlayerIndex = (currentHighPlayerIndex + 1) % playerPoolSize
                }
            } else {
                // Use next player from pool
                if !lowBeatPlayers.isEmpty {
                    let player = lowBeatPlayers[currentLowPlayerIndex]
                    player.stop()
                    player.currentTime = 0
                    player.play()
                    currentLowPlayerIndex = (currentLowPlayerIndex + 1) % playerPoolSize
                }
            }
        }
    }
    
    private func prepareHaptic() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
    
    private func triggerHapticFeedback(strong: Bool = false) {
        let generator = UIImpactFeedbackGenerator(style: strong ? .heavy : .medium)
        generator.impactOccurred()
    }
    
    private func cleanupAudioPlayers() {
        // Properly dispose of audio players to prevent memory leaks
        for player in highBeatPlayers {
            player.stop()
        }
        for player in lowBeatPlayers {
            player.stop()
        }
        highBeatPlayers.removeAll()
        lowBeatPlayers.removeAll()
        currentHighPlayerIndex = 0
        currentLowPlayerIndex = 0
    }
    
    private func loadSounds() {
        guard let highBeatURL = Bundle.main.url(forResource: "Perc_MetronomeQuartz_hi", withExtension: "wav"),
              let lowBeatURL = Bundle.main.url(forResource: "Perc_MetronomeQuartz_lo", withExtension: "wav") else {
            print("Could not find sound files in bundle")
            return
        }
        
        // Create player pool for reliable high-tempo playback
        highBeatPlayers.removeAll()
        lowBeatPlayers.removeAll()
        
        do {
            // Create multiple instances of each player
            for _ in 0..<playerPoolSize {
                let highPlayer = try AVAudioPlayer(contentsOf: highBeatURL)
                highPlayer.prepareToPlay()
                highPlayer.volume = soundVolume
                highPlayer.numberOfLoops = 0
                highBeatPlayers.append(highPlayer)
                
                let lowPlayer = try AVAudioPlayer(contentsOf: lowBeatURL)
                lowPlayer.prepareToPlay()
                lowPlayer.volume = soundVolume
                lowPlayer.numberOfLoops = 0
                lowBeatPlayers.append(lowPlayer)
            }
            print("Loaded \(playerPoolSize) audio players for each sound")
        } catch {
            print("Failed to load sound: \(error)")
        }
    }
    
    private func registerTap() {
        tapTimes.append(Date())
        
        // Provide immediate visual feedback
        withAnimation(.easeInOut(duration: 0.1)) {
            pulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                pulse = false
            }
        }
        
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
            let intervals = zip(tapTimes, tapTimes.dropFirst()).map { $1.timeIntervalSince($0) }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let newBPM = Int(60 / averageInterval)
            let clampedBPM = min(max(newBPM, 40), 240)
            
            // Add to history if different from current
            if clampedBPM != bpm && !bpmHistory.contains(clampedBPM) {
                bpmHistory.append(clampedBPM)
                if bpmHistory.count > 10 {
                    bpmHistory.removeFirst()
                }
            }
            
            bpm = clampedBPM
            updateSliderPosition()
            updateTimer()
            
            // Visual feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                showTapInfo = false
            }
        }
    }
    
    private func prepareAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.interruptSpokenAudioAndMixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session:", error)
        }
    }
    
    // MARK: - AI Helper Functions
    
    private func calculateTempoConsistency() {
        let tempos = sessionMetrics.tempoChanges
        guard tempos.count >= 3 else { return }
        
        let recent = Array(tempos.suffix(10))
        let mean = Float(recent.reduce(0, +)) / Float(recent.count)
        let variance = recent.map { pow(Float($0) - mean, 2) }.reduce(0, +) / Float(recent.count)
        tempoConsistency = max(0, 1 - (variance / 1000)) // Normalize
    }
    
    private func suggestNextTempo() {
        let tempos = sessionMetrics.tempoChanges
        guard tempos.count >= 3 else { return }
        
        let recent = Array(tempos.suffix(5))
        let isIncreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 <= $1 }
        
        if isIncreasing && bpm < 200 {
            // Suggest 5-10% increase for progressive practice
            let increment = max(5, Int(Float(bpm) * 0.08))
            suggestedNextTempo = min(240, bpm + increment)
        } else if bpm > 60 {
            // Suggest slowing down for accuracy
            let decrement = max(5, Int(Float(bpm) * 0.1))
            suggestedNextTempo = max(40, bpm - decrement)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    private func tempoTrendIcon() -> String {
        let tempos = sessionMetrics.tempoChanges
        guard tempos.count >= 3 else { return "chart.bar" }
        let recent = Array(tempos.suffix(5))
        let isIncreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 <= $1 }
        let isDecreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 >= $1 }
        
        if isIncreasing { return "arrow.up.right.circle.fill" }
        if isDecreasing { return "arrow.down.right.circle.fill" }
        return "arrow.left.and.right.circle.fill"
    }
    
    private func tempoTrendColor() -> Color {
        let tempos = sessionMetrics.tempoChanges
        guard tempos.count >= 3 else { return .cyan }
        let recent = Array(tempos.suffix(5))
        let isIncreasing = zip(recent, recent.dropFirst()).allSatisfy { $0 <= $1 }
        
        return isIncreasing ? .green : .cyan
    }
}

struct MetronomeView_Preview: PreviewProvider {
    static var previews: some View {
        MetronomeView(isStarted: .constant(true), sessionMetrics: .constant(SessionMetrics()))
    }
}
