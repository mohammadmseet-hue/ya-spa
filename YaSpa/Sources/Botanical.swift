import SwiftUI

// MARK: - Botanical imagery + living backgrounds (Sage & Jasmine)
// The premium visual layer: iOS-18 mesh gradients that read like soft-focus photography,
// hand-drawn jasmine blooms and sprigs as real botanical imagery, and gentle drifting
// petals so the app feels alive. All motion is gated off in UI tests and Reduce Motion.

// MARK: Mesh canvas

/// A lush sage / linen / gold mesh gradient — the signature "canvas" behind heroes and
/// screens. Renders like a soft botanical photograph. Static by default (rock-solid); the
/// `.hero` variant is deeper and greener for banner moments.
struct SageMesh: View {
    enum Tone { case canvas, hero }
    var tone: Tone = .canvas

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0, 0),   .init(0.5, 0),   .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1),   .init(0.5, 1),   .init(1, 1),
            ],
            colors: tone == .hero ? heroColors : canvasColors
        )
    }

    private var canvasColors: [Color] {
        [
            Color(light: 0xEEF2E4, dark: 0x18200F), Color(light: 0xE3ECD5, dark: 0x1C2614), Color(light: 0xF4F1E7, dark: 0x1A1E12),
            Color(light: 0xDDEACC, dark: 0x22301C), Color(light: 0xCFE1BE, dark: 0x2A3A22), Color(light: 0xEDE6D2, dark: 0x24170F),
            Color(light: 0xEAF0DF, dark: 0x161B10), Color(light: 0xDCE8CC, dark: 0x1F2916), Color(light: 0xF5F2EA, dark: 0x14180F),
        ]
    }

    private var heroColors: [Color] {
        [
            Color(light: 0xCFE0BC, dark: 0x27381F), Color(light: 0xBFD5A9, dark: 0x2E4326), Color(light: 0xE8E7CE, dark: 0x2A2011),
            Color(light: 0xB7D1A0, dark: 0x35492B), Color(light: 0x9FBE8A, dark: 0x3E5730), Color(light: 0xDCD9B4, dark: 0x30240F),
            Color(light: 0xD8E7C6, dark: 0x1F2E18), Color(light: 0xCBE0B4, dark: 0x293A20), Color(light: 0xEDEFDC, dark: 0x1A2312),
        ]
    }
}

// MARK: Jasmine bloom (drawn botanical imagery)

/// A five-petal jasmine flower — cream petals, soft gold pistil. The brand's signature
/// botanical, drawn as crisp vector art so it renders perfectly at any size.
struct JasmineBloom: View {
    var size: CGFloat = 120
    var petal: Color = Color(hex: 0xFBFBF4)
    var pistil: Color = Brand.gold
    var tint: Color = Color(hex: 0xEFF3E6)   // faint sage on the petal base

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(
                        LinearGradient(colors: [petal, tint],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.36, height: size * 0.62)
                    .overlay(
                        Ellipse().stroke(Brand.sage.opacity(0.15), lineWidth: 0.5)
                    )
                    .offset(y: -size * 0.21)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(RadialGradient(colors: [Brand.gold, Brand.gold.opacity(0.65)],
                                     center: .center, startRadius: 0, endRadius: size * 0.12))
                .frame(width: size * 0.2, height: size * 0.2)
        }
        .frame(width: size, height: size)
        .shadow(color: Brand.sage.opacity(0.18), radius: size * 0.06, y: size * 0.03)
        .accessibilityHidden(true)
    }
}

/// A leaf used to build sprigs.
private struct Leaf: View {
    var length: CGFloat
    var color: Color = Brand.sage
    var body: some View {
        Capsule(style: .continuous)
            .fill(LinearGradient(colors: [color, color.opacity(0.75)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: length * 0.42, height: length)
            .clipShape(LeafShape())
            .accessibilityHidden(true)
    }
}

private struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A small jasmine sprig — a bloom flanked by two leaves. Decorative botanical imagery
/// for hero corners and card accents.
struct JasmineSprig: View {
    var size: CGFloat = 90
    var body: some View {
        ZStack {
            Leaf(length: size * 0.7).rotationEffect(.degrees(-42)).offset(x: -size * 0.26, y: size * 0.12)
            Leaf(length: size * 0.6).rotationEffect(.degrees(38)).offset(x: size * 0.24, y: size * 0.16)
            JasmineBloom(size: size * 0.72)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: Drifting petals (life)

/// A few jasmine petals drifting slowly upward — the "alive" layer. Purely decorative,
/// and completely still in UI tests / Reduce Motion so nothing ever reads as a glitch.
struct DriftingPetals: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var count: Int = 6
    var tint: Color = Color(hex: 0xFBFBF4)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Petal(index: i, area: geo.size, tint: tint,
                          animate: !reduceMotion && !Runtime.isUITest)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Petal: View {
        let index: Int
        let area: CGSize
        let tint: Color
        let animate: Bool
        @State private var drift = false

        private var seedX: CGFloat { CGFloat((index * 97) % 100) / 100 }
        private var scale: CGFloat { 0.6 + CGFloat((index * 53) % 40) / 100 }
        private var dur: Double { 9 + Double((index * 37) % 60) / 10 }

        var body: some View {
            Ellipse()
                .fill(tint.opacity(0.55))
                .frame(width: 14 * scale, height: 22 * scale)
                .rotationEffect(.degrees(drift ? 220 : 0))
                .position(x: area.width * (0.08 + seedX * 0.84),
                          y: drift ? -40 : area.height + 40)
                .onAppear {
                    guard animate else { return }
                    withAnimation(.linear(duration: dur).repeatForever(autoreverses: false).delay(Double(index) * 0.9)) {
                        drift = true
                    }
                }
        }
    }
}

// MARK: Reusable hero banner

/// The signature dashboard/hero banner: a mesh canvas, drifting petals, a jasmine sprig,
/// and whatever content the caller layers on top — all inside a soft rounded card with a
/// gold hairline. This is the "picture" that makes a screen feel designed.
struct BotanicalHero<Content: View>: View {
    var height: CGFloat = 210
    var corner: CGFloat = Radius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            SageMesh(tone: .hero)
            LinearGradient(colors: [.clear, Brand.paper.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
            DriftingPetals(count: 7)
            JasmineSprig(size: 118)
                .rotationEffect(.degrees(18))
                .offset(x: 120, y: -58)
                .opacity(0.9)
            JasmineBloom(size: 46)
                .offset(x: -130, y: 66)
                .opacity(0.85)
            content()
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Brand.gold.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Brand.shadowBloom.opacity(0.10), radius: 20, y: 12)
    }
}
