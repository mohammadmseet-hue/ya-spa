import SwiftUI

/// Launch/loading screen: the mark centered on the sugar off-white ground, with
/// a soft scale + fade in and a quiet gold halo. Shown briefly at cold start.
struct SplashView: View {
    @State private var appear = false
    @State private var halo = false

    var body: some View {
        ZStack {
            Logo.sugar.ignoresSafeArea()

            // faint gold halo behind the mark
            Circle()
                .fill(RadialGradient(colors: [Logo.gold.opacity(0.16), .clear],
                                     center: .center, startRadius: 4, endRadius: 220))
                .frame(width: 440, height: 440)
                .scaleEffect(halo ? 1 : 0.7)
                .opacity(halo ? 1 : 0)

            VStack(spacing: 22) {
                YaSpaLogoMark(height: 132)
                    .scaleEffect(appear ? 1 : 0.86)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: 6) {
                    Text("يا سبا")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(Logo.forest)
                    Text("YA SPA")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(Logo.grass)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) { appear = true }
            withAnimation(.easeOut(duration: 1.1)) { halo = true }
        }
    }
}
