import SwiftUI

struct TunerView: View {
    @Binding var isStarted: Bool
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.green, .mint]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                    .shadow(color: .cyan.opacity(0.5), radius: 50.0)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 100)
            }
        }
    }
}

#Preview {
    TunerView(isStarted: .constant(false))
}
