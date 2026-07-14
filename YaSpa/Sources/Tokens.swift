import SwiftUI
import UIKit

// MARK: - Design tokens ("quiet luxury at-home hammam")
// Additive layer on top of Brand. Screens consume these instead of ad-hoc values.

extension Brand {
    static let inkSoft     = Color(light: 0x6E7A66, dark: 0xA6AE9C)   // secondary text/icons
    static let shadowRose  = Color(light: 0x2C3A2E, dark: 0x000000)   // tight contact shadow
    static let shadowBloom = Color(light: 0x47654E, dark: 0x000000)   // wide sage ambient bloom

    /// Deterministic botanical-tone gradient seeded from a string (photo-free people identity).
    /// A soft two-tone disc (sage / terracotta / gold / pine) with ivory initials — richer than
    /// the old flat fill so avatars feel alive.
    static func monogramGradient(seed: String) -> LinearGradient {
        let tones: [(UInt, UInt)] = [
            (0x5B7B58, 0x3C5340),   // sage
            (0xC88A6A, 0xA96A4C),   // terracotta
            (0xB4894A, 0x8C6636),   // gold
            (0x47654E, 0x2C3A2E),   // pine
        ]
        // Deterministic djb2 over the bytes: stable across launches (Swift's String.hashValue is
        // per-process randomized, so it re-colored avatars every open) and overflow-safe — `abs`
        // on a hashValue of Int.min traps, and `&*`/`&+` can never overflow-trap.
        var h: UInt64 = 5381
        for b in seed.utf8 { h = (h &* 33) &+ UInt64(b) }
        let (top, bottom) = tones[Int(h % UInt64(tones.count))]
        return LinearGradient(colors: [Color(hex: top), Color(hex: bottom)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
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

extension Font {
    /// Rubik at a given size/weight (both scripts), with a rounded-system fallback.
    /// The body-text counterpart to spaFont's display roles.
    static func rubik(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black: name = SpaFont.rubikSemibold
        case .medium:                          name = SpaFont.rubikMedium
        default:                               name = SpaFont.rubik
        }
        return SpaFont.of(name, size, relativeTo: .body, fallback: .rounded, weight: weight)
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

/// Warm canvas + two soft, STATIC blurred blobs. Static on purpose — a drifting blur
/// read as a "black thing moving in the corner" in dusk mode, so nothing animates here.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Brand.bg
            blob(Brand.sage.opacity(0.16), size: 360).offset(x: 150, y: -260)
            blob(Brand.gold.opacity(0.10), size: 300).offset(x: -160, y: 300)
            blob(Brand.terra.opacity(0.07), size: 250).offset(x: 130, y: 400)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)   // decorative canvas
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

// MARK: - Staggered entrance (premium list reveal; off in tests / Reduce Motion)

struct StaggerAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        let animate = !reduceMotion && !Runtime.isUITest
        content
            .opacity(animate ? (shown ? 1 : 0) : 1)
            .offset(y: animate ? (shown ? 0 : 14) : 0)
            .animation(animate ? .spring(response: 0.45, dampingFraction: 0.85)
                        .delay(Double(index) * 0.05) : nil, value: shown)
            .onAppear { if animate { shown = true } }
    }
}

extension View {
    func staggerAppear(_ index: Int) -> some View { modifier(StaggerAppear(index: index)) }
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
