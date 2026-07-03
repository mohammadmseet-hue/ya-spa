import SwiftUI
import UIKit

// MARK: - Design tokens ("quiet luxury at-home hammam")
// Additive layer on top of Brand. Screens consume these instead of ad-hoc values.

extension Brand {
    static let inkSoft     = Color(hex: 0x6B5F58)   // Taupe-Grey secondary text/icons
    static let shadowRose  = Color(hex: 0x2A2320)   // warm-neutral tight contact shadow
    static let shadowBloom = Color(hex: 0x6E1E2E)   // bordeaux wide ambient bloom (restrained)

    /// Deterministic FLAT earth-tone fill seeded from a string (photo-free identity).
    /// No pink→gold gradient — a quiet tonal disc with ivory initials.
    static func monogramGradient(seed: String) -> LinearGradient {
        let tones = [Color(hex: 0x6E1E2E), Color(hex: 0x2A2320), Color(hex: 0x8A5A3C), Color(hex: 0x6B5F58)]
        let c = tones[abs(seed.hashValue) % tones.count]
        return LinearGradient(colors: [c, c], startPoint: .top, endPoint: .bottom)
    }
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let huge: CGFloat = 32
    static let hero: CGFloat = 44
    static let screen: CGFloat = 20   // horizontal screen inset
}

enum Radius {
    static let card: CGFloat = 24
    static let sheet: CGFloat = 28
    static let chip: CGFloat = 14
    static let tag: CGFloat = 8
}

enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let press  = Animation.spring(response: 0.3, dampingFraction: 0.6)
}

// MARK: - Typography (bundled: Fraunces + El Messiri for Arabic display, Rubik for body)

/// Bundled font PostScript names (verified from the instanced .ttf name tables) with a
/// runtime fallback so text NEVER disappears if a name is wrong or a font fails to load.
enum SpaFont {
    static let frauncesRegular  = "Fraunces-72ptNonWonky"
    static let frauncesSemibold = "Fraunces-72ptSemiBoldNonWonky"
    static let elMessiriSemibold = "ElMessiri-SemiBold"
    static let elMessiriBold     = "ElMessiri-Bold"
    static let rubik         = "Rubik-Regular"
    static let rubikMedium   = "Rubik-Medium"
    static let rubikSemibold = "Rubik-SemiBold"

    static func of(_ name: String, _ size: CGFloat, relativeTo style: Font.TextStyle,
                   fallback: Font.Design = .default, weight: Font.Weight = .regular) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(size: size, weight: weight, design: fallback)   // safe fallback
    }
}

enum Typo {
    case display, serviceName, price, section, cardTitle, body, subhead, caption, eyebrow, micro

    func font(ar: Bool) -> Font {
        switch self {
        case .display:     return SpaFont.of(ar ? SpaFont.elMessiriBold : SpaFont.frauncesSemibold,
                                              ar ? 30 : 32, relativeTo: .largeTitle,
                                              fallback: ar ? .rounded : .serif, weight: .semibold)
        case .serviceName: return SpaFont.of(ar ? SpaFont.elMessiriBold : SpaFont.frauncesSemibold,
                                              24, relativeTo: .title,
                                              fallback: ar ? .rounded : .serif, weight: .semibold)
        case .price:       return SpaFont.of(ar ? SpaFont.elMessiriSemibold : SpaFont.frauncesSemibold,
                                              22, relativeTo: .title2,
                                              fallback: ar ? .rounded : .serif, weight: .bold)
        case .section:     return SpaFont.of(SpaFont.rubikSemibold, 20, relativeTo: .title3,
                                              fallback: .rounded, weight: .semibold)
        case .cardTitle:   return SpaFont.of(SpaFont.rubikSemibold, 17, relativeTo: .headline,
                                              fallback: .rounded, weight: .semibold)
        case .body:        return SpaFont.of(SpaFont.rubik, 16, relativeTo: .body, fallback: .rounded)
        case .subhead:     return SpaFont.of(SpaFont.rubik, 15, relativeTo: .subheadline, fallback: .rounded)
        case .caption:     return SpaFont.of(SpaFont.rubikMedium, 13, relativeTo: .caption,
                                              fallback: .rounded, weight: .medium)
        case .eyebrow:     return SpaFont.of(SpaFont.rubikSemibold, 12, relativeTo: .caption,
                                              fallback: .rounded, weight: .semibold)
        case .micro:       return SpaFont.of(SpaFont.rubikMedium, 11, relativeTo: .caption2,
                                              fallback: .rounded, weight: .medium)
        }
    }
}

extension View {
    func spaFont(_ role: Typo, ar: Bool) -> some View { font(role.font(ar: ar)) }
}

// MARK: - Ambient background (the #1 premium lever)

/// Warm cream canvas + heavily-blurred rose/gold/deep-rose blobs that gently drift.
/// Drop in behind screens instead of a flat fill. Drift is disabled in tests / reduce-motion.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Brand.bg
            blob(Brand.pinkSoft.opacity(0.30), size: 320)
                .offset(x: drift ? 120 : 150, y: -260)
            blob(Brand.gold.opacity(0.10), size: 300)
                .offset(x: -150, y: drift ? 340 : 300)
        }
        .ignoresSafeArea()
        // Scope the repeating animation to `drift` ONLY so it never leaks into
        // tab/navigation transitions (the cause of the "terrible" animation).
        .animation(driftAnimation, value: drift)
        .onAppear { if !reduceMotion && !Runtime.isUITest { drift = true } }
    }

    private var driftAnimation: Animation? {
        (reduceMotion || Runtime.isUITest) ? nil
            : .easeInOut(duration: 12).repeatForever(autoreverses: true)
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 40)
    }
}

// MARK: - Soft card depth (double rose-tinted shadow + lit edge)

struct SoftCard: ViewModifier {
    var radius: CGFloat = Radius.card
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Brand.paper)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(selected ? Brand.accent.opacity(0.55) : Brand.hairline,
                            lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: Brand.shadowRose.opacity(0.07), radius: 7, y: 3)
            .shadow(color: Brand.shadowBloom.opacity(selected ? 0.08 : 0.05),
                    radius: selected ? 16 : 22, y: selected ? 7 : 12)
    }
}

extension View {
    func softCard(radius: CGFloat = Radius.card, selected: Bool = false) -> some View {
        modifier(SoftCard(radius: radius, selected: selected))
    }
}

// MARK: - Press interaction for tappable cards/rows

/// Subtle press-scale + light haptic, no visual chrome. NavigationLink and Button both
/// respect this, and stay queryable as `buttons` for the UI tests.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { Haptics.tap() }
            }
    }
}
