import SwiftUI
import Combine
import CoreHaptics
import AVFoundation

struct MetronomeView: View {
    
    @Binding var isStarted: Bool
    @State private var pulse = false
    
    @State private var dragOffsetRight: CGFloat = 0
    @State private var currentOffsetRight: CGFloat = 0
    @State private var isDraggingRight = false
    @State private var dragStartYRight: CGFloat = 0
    
    @State private var dragOffsetLeft: CGFloat = 0
    @State private var currentOffsetLeft: CGFloat = 0
    @State private var isDraggingLeft = false
    @State private var dragStartYLeft: CGFloat = 0
    
    @State private var bpm: Int = 40
    @State private var timeSignatureIndex: Int = 0
    @State private var beatCounter: Int = 0
    
    @State private var highBeatPlayer: AVAudioPlayer?
    @State private var lowBeatPlayer: AVAudioPlayer?
    
    let leftDotPositions: [CGFloat] = (0..<10).map { CGFloat($0) * (240 / 9) }
    let rightDotPositions: [CGFloat] = (0..<8).map { CGFloat($0) * (240 / 7) }
    let timeSignatures = ["4/4", "2/4", "3/4", "6/4", "2/2", "3/2", "4/2", "6/8", "9/8", "12/8"]
    
    @State private var hapticEngine: CHHapticEngine?
    @State private var timer: AnyCancellable?
    
    @State private var highlightedDot: Int? = nil
    @State private var tapTimes: [Date] = []
    
    @State private var compareProBPM: Bool = false
    @State private var proBPM: Int = 120
    @State private var compareFeedback: String = ""
    
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
                mainCircle
                rightSlider(in: geometry)
                leftSlider(in: geometry)
            }
            .onAppear {
                prepareAudioSession()
                prepareHaptic()
                loadSounds()
                updateTimer()
            }
            .onChange(of: isStarted) { started in
                if started {
                    beatCounter = 0
                    updateTimer()
                } else {
                    timer?.cancel()
                    pulse = false
                    highlightedDot = nil
                }
            }
            .onChange(of: bpm) { _ in
                updateTimer()
                updateCompareFeedback()
            }
            .onChange(of: timeSignatureIndex) { _ in
                beatCounter = 0
            }
            .onChange(of: compareProBPM) { _ in
                updateCompareFeedback()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundOverlay: some View {
        Color.black.opacity(isDraggingLeft || isDraggingRight ? 0.3 : 0.0)
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut, value: isDraggingLeft || isDraggingRight)
    }
    
    private var mainCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.indigo, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .shadow(color: .blue.opacity(0.5), radius: pulse ? 50 : 10, x: 0, y: pulse ? 10 : 5)
                .animation(.easeInOut(duration: beatInterval / 3), value: pulse)
                .glassEffect()
                .onTapGesture {
                    withAnimation { pulse.toggle() }
                    registerTap()
                }
            
            ForEach(0..<currentTopNumber, id: \.self) { i in
                let angle = Double(i) / Double(currentTopNumber) * 2 * Double.pi
                let baseRadius: CGFloat = 60
                let scale: CGFloat = pulse ? 1.3 : 1.0
                let animatedRadius = baseRadius * scale
                let x = CGFloat(cos(angle)) * animatedRadius
                let y = CGFloat(sin(angle)) * animatedRadius
                
                Circle()
                    .fill(highlightedDot == i ? Color.yellow : Color.white)
                    .frame(width: 8, height: 8)
                    .offset(x: x, y: y)
                    .animation(.easeInOut(duration: beatInterval / 3), value: highlightedDot)
            }
        }
    }
    
    private func rightSlider(in geometry: GeometryProxy) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: isDraggingRight ? 40 : 30, height: 275)
                    .glassEffect()
                    .overlay(
                        VStack(spacing: 0) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue)
                                .frame(height: dragOffsetRight)
                        }
                    )
                    .position(x: geometry.size.width - 30, y: geometry.size.height / 2)
                    .shadow(color: isDraggingRight ? Color.blue.opacity(0.5) : Color.clear, radius: isDraggingRight ? 10 : 0)
                
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(
                            x: geometry.size.width - 30,
                            y: geometry.size.height / 2 - (120 - rightDotPositions[index])
                        )
                        .onTapGesture { triggerHapticFeedback() }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let sliderHeight: CGFloat = 275
                        if dragStartYRight == 0 { dragStartYRight = value.startLocation.y }
                        let delta = dragStartYRight - value.location.y
                        dragOffsetRight = max(0, min(275, currentOffsetRight + delta))
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
            
            VStack {
                Text("\(bpm)").fontWeight(.bold)
                Text("BPM").fontWeight(.bold)
            }
            .position(x: geometry.size.width - 30, y: geometry.size.height / 2 - 200)
        }
    }
    
    private func leftSlider(in geometry: GeometryProxy) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.secondary.opacity(0.7))
                    .glassEffect()
                    .frame(width: isDraggingLeft ? 40 : 30, height: 275)
                    .overlay(
                        VStack(spacing: 0) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue)
                                .frame(height: dragOffsetLeft)
                        }
                    )
                    .position(x: 30, y: geometry.size.height / 2)
                    .shadow(color: isDraggingLeft ? Color.blue.opacity(0.5) : Color.clear, radius: isDraggingLeft ? 10 : 0)
                
                ForEach(0..<10, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(
                            x: 30,
                            y: geometry.size.height / 2 - (120 - leftDotPositions[index])
                        )
                        .onTapGesture { triggerHapticFeedback() }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartYLeft == 0 { dragStartYLeft = value.startLocation.y }
                        let delta = dragStartYLeft - value.location.y
                        dragOffsetLeft = max(0, min(275, currentOffsetLeft + delta))
                        
                        // Update continuously while dragging
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
            
            Text(timeSignatures[timeSignatureIndex])
                .position(x: 30, y: geometry.size.height / 2 - 200)
                .fontWeight(.bold)
        }
    }
    
    // MARK: - Functions
    
    private func updateTimer() {
        timer?.cancel()
        guard isStarted else { return }
        pulse = false
        timer = Timer.publish(every: beatInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation {
                    pulse.toggle()
                    highlightedDot = beatCounter % currentTopNumber
                }
                playSound(beat: beatCounter % currentTopNumber == 0)
                triggerHapticFeedback()
                beatCounter += 1
            }
    }
    
    private func playSound(beat: Bool) {
        if beat { highBeatPlayer?.play() } else { lowBeatPlayer?.play() }
    }
    
    private func prepareHaptic() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch { print("Haptic engine error: \(error.localizedDescription)") }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func loadSounds() {
        if let highBeatURL = Bundle.main.url(forResource: "Perc_MetronomeQuartz_hi", withExtension: "wav"),
           let lowBeatURL = Bundle.main.url(forResource: "Perc_MetronomeQuartz_lo", withExtension: "wav") {
            do {
                highBeatPlayer = try AVAudioPlayer(contentsOf: highBeatURL)
                lowBeatPlayer = try AVAudioPlayer(contentsOf: lowBeatURL)
                highBeatPlayer?.prepareToPlay()
                lowBeatPlayer?.prepareToPlay()
                
                // Full volume
                highBeatPlayer?.volume = 1.0
                lowBeatPlayer?.volume = 1.0
            } catch { print("Failed to load sound: \(error)") }
        } else { print("Could not find sound files in bundle") }
    }
    
    private func registerTap() {
        tapTimes.append(Date())
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
            let intervals = zip(tapTimes, tapTimes.dropFirst()).map { $1.timeIntervalSince($0) }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let newBPM = Int(60 / averageInterval)
            bpm = min(max(newBPM, 40), 240)
            updateTimer()
            updateCompareFeedback()
        }
    }
    
    private func updateCompareFeedback() {
        guard compareProBPM else { compareFeedback = ""; return }
        let diff = bpm - proBPM
        if abs(diff) <= 5 { compareFeedback = "In time" }
        else if diff > 5 { compareFeedback = "Playing fast" }
        else { compareFeedback = "Playing slow" }
    }
    
    private func prepareAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.interruptSpokenAudioAndMixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Failed to set up audio session:", error) }
    }
}

struct MetronomeView_Preview: PreviewProvider {
    static var previews: some View {
        MetronomeView(isStarted: .constant(true))
    }
}
