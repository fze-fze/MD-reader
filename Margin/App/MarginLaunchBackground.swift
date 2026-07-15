import SwiftUI

struct MarginLaunchBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xF9DDA8), Color(hex: 0xE98638)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 48)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: geometry.size.width * 1.35, height: 170)
                    .rotationEffect(.degrees(14))
                    .offset(x: -40, y: -geometry.size.height * 0.28)

                RoundedRectangle(cornerRadius: 52)
                    .fill(Color.orange.opacity(0.16))
                    .frame(width: geometry.size.width * 1.4, height: 190)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 55, y: geometry.size.height * 0.05)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }
}
