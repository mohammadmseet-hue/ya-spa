import SwiftUI

// MARK: - Keyhole / mihrab arch (Hijazi hammam niche) — the app's signature silhouette

/// A pointed keyhole arch: straight sides, a pointed mihrab crown (two quad curves to an
/// apex), and softly rounded bottom corners. Horizontally symmetric — needs no RTL flip.
struct ArchShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width, r.height) * 0.16      // bottom corner radius
        let spring = r.minY + r.width / 2          // where the crown springs from

        p.move(to: CGPoint(x: r.minX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: spring))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: spring), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addArc(center: CGPoint(x: r.maxX - s, y: r.maxY - s), radius: s,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + s, y: r.maxY - s), radius: s,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// An SF Symbol set inside a mihrab arch niche with a soft rose tint + gold hairline.
/// The photo-free identity mark for hero / service moments.
struct ArchMedallion: View {
    let symbol: String
    var width: CGFloat = 64
    var height: CGFloat = 80

    var body: some View {
        ZStack {
            ArchShape()
                .fill(
                    LinearGradient(colors: [Color(hex: 0xE7EFDB), Color(hex: 0xF3F0E6)],
                                   startPoint: .top, endPoint: .bottom)
                )
            ArchShape()
                .fill(RadialGradient(colors: [Brand.sage.opacity(0.22), .clear],
                                     center: .center, startRadius: 2, endRadius: width * 0.85))
            ArchShape().stroke(Brand.gold.opacity(0.55), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: width * 0.42, weight: .regular))
                .foregroundStyle(Brand.accent)
                .offset(y: height * 0.06)
        }
        .frame(width: width, height: height)
        .shadow(color: Brand.sage.opacity(0.14), radius: width * 0.08, y: width * 0.05)
        .accessibilityHidden(true)   // decorative — the label sits beside it
    }
}

// MARK: - Opaque presentation floor (fullScreenCover never flashes black)

extension View {
    @ViewBuilder func opaqueCover() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Brand.bg)
        } else {
            self   // content already carries an opaque AmbientBackground floor
        }
    }
}

// MARK: - Gold hairline frame

extension View {
    func goldFrame(_ radius: CGFloat = Radius.card, width w: CGFloat = 1) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Brand.gold.opacity(0.5), lineWidth: w)
        )
    }
}

// MARK: - Hijazi jasmine chapter divider

struct JasmineDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            fade
            Image(systemName: "seal").font(.system(size: 9)).foregroundStyle(Brand.gold)
            fade
        }
        .accessibilityHidden(true)   // purely decorative chapter divider
    }
    private var fade: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Brand.gold.opacity(0.5), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.75)
    }
}

// MARK: - Locked-up bilingual wordmark

struct YaSpaWordmark: View {
    @EnvironmentObject var app: AppState
    var compact: Bool = false
    var onDark: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(app.t("يا سبا", "Ya Spa"))
                .font(SpaFont.of(app.isAr ? SpaFont.elMessiriBold : SpaFont.frauncesSemibold,
                                 compact ? 20 : 24, relativeTo: .title,
                                 fallback: app.isAr ? .rounded : .serif, weight: .semibold))
                .tracking(app.isAr ? 0 : -0.6)
                .foregroundStyle(onDark ? Brand.gold : Brand.accent)
            HStack(spacing: 4) {
                rule
                Image(systemName: "seal").font(.system(size: 8)).foregroundStyle(Brand.gold.opacity(0.85))
                rule
            }
            .frame(width: 44)
            if !compact {
                Text(app.t("نساء فقط · جدة", "WOMEN ONLY · JEDDAH"))
                    .font(.rubik(10, .medium))
                    .tracking(app.isAr ? 0 : 2)
                    .foregroundStyle(onDark ? Brand.ivory.opacity(0.8) : Brand.muted)
            }
        }
    }

    private var rule: some View {
        Rectangle().fill(Brand.gold.opacity(0.5)).frame(height: 1)
    }
}
