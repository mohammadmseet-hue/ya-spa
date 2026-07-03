import SwiftUI

// MARK: - Photo-free identity: symbol medallions + monogram avatars

/// A service's SF Symbol on a soft radial-rose medallion. The photo replacement.
struct SFSymbolMedallion: View {
    let symbol: String
    var size: CGFloat = 56
    var rounded: Bool = false

    var body: some View {
        ZStack {
            let fill = RadialGradient(colors: [Brand.bg2, Brand.pinkSoft.opacity(0.35)],
                                     center: .center, startRadius: 2, endRadius: size * 0.6)
            if rounded {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(fill)
            } else {
                Circle().fill(fill)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(Brand.brandGradient)
        }
        .frame(width: size, height: size)
    }
}

/// Deterministic rose→gold gradient + initials. Photo-free identity for people.
struct GradientMonogramAvatar: View {
    let seed: String
    let initials: String
    var size: CGFloat = 44
    var verified: Bool = false

    var body: some View {
        Circle()
            .fill(Brand.monogramGradient(seed: seed))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.ivory)
            )
            .overlay(alignment: .bottomTrailing) {
                if verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: size * 0.32))
                        .foregroundStyle(Brand.gold)
                        .background(Circle().fill(Brand.paper).padding(-1))
                        .offset(x: 2, y: 2)
                }
            }
    }
}

// MARK: - Stars

struct StarRow: View {
    let rating: Double
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: name(for: i))
                    .font(.system(size: size))
                    .foregroundStyle(Brand.gold)
            }
        }
    }

    private func name(for i: Int) -> String {
        let r = rating - Double(i)
        if r >= 1 { return "star.fill" }
        if r >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Chips

struct MetadataChip: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(Brand.inkSoft)
    }
}

struct BenefitChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Brand.pinkDeep)
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(Brand.bg2)
            .clipShape(Capsule())
    }
}

struct PressureIndicator: View {
    let label: String
    let level: Int   // 1 gentle · 2 medium · 3 firm

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(1...3, id: \.self) { i in
                    Capsule()
                        .fill(i <= level ? Brand.pink : Brand.pinkSoft.opacity(0.5))
                        .frame(width: 5, height: 9)
                }
            }
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Brand.inkSoft).lineLimit(1).fixedSize()
        }
    }

    static func level(for pressureEn: String) -> Int {
        switch pressureEn.lowercased() {
        case "gentle": return 1
        case "firm":   return 3
        default:       return 2
        }
    }
}

// MARK: - Trust (KSA conversion engine)

struct PromiseStrip: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        HStack(spacing: Space.m) {
            TrustPromiseCard(icon: "checkmark.seal.fill",
                             title: app.t("موثّقات", "Verified"), sub: app.t("نساء فقط", "Women only"))
            TrustPromiseCard(icon: "lock.shield.fill",
                             title: app.t("خصوصية", "Privacy"), sub: app.t("بيتكِ فقط", "Your home"))
            TrustPromiseCard(icon: "drop.fill",
                             title: app.t("زيوت فاخرة", "Premium oils"), sub: app.t("معتمدة", "SFDA"))
        }
    }
}

struct TrustPromiseCard: View {
    let icon: String
    let title: String
    let sub: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Brand.gold)
            Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
            Text(sub).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 6)
        .background(Brand.paper)
        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                .stroke(Brand.gold.opacity(0.25), lineWidth: 1)
        )
        .multilineTextAlignment(.center)
    }
}

// MARK: - Sticky glass bottom bar

struct StickyGlassBar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.m)
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .top) {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(Brand.gold.opacity(0.4)).frame(height: 1)
                }
            )
    }
}

// MARK: - Success moment

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct AnimatedCheckmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draw = false
    var size: CGFloat = 112

    var body: some View {
        ZStack {
            Circle().fill(Brand.paper)
                .shadow(color: Brand.shadowBloom.opacity(0.18), radius: 24, y: 12)
            Circle().stroke(Brand.gold, lineWidth: 3)
            CheckmarkShape()
                .trim(from: 0, to: draw ? 1 : 0)
                .stroke(Brand.pinkDeep, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.44, height: size * 0.32)
        }
        .frame(width: size, height: size)
        .onAppear {
            Haptics.success()
            if reduceMotion || Runtime.isUITest { draw = true }
            else { withAnimation(.easeOut(duration: 0.5).delay(0.15)) { draw = true } }
        }
    }
}

// MARK: - Booking step progress (visual cue only, RTL-aware via layout)

struct StepProgress: View {
    let total: Int
    let current: Int   // 0-based highest reached step
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? AnyShapeStyle(Brand.brandGradient)
                                       : AnyShapeStyle(Brand.pinkSoft.opacity(0.4)))
                    .frame(height: 5)
            }
        }
    }
}

// MARK: - Reviews module

struct RatingSummary: View {
    @EnvironmentObject var app: AppState
    let average: Double
    let count: Int
    let distribution: [Int]   // [5★, 4★, 3★, 2★, 1★]

    var body: some View {
        HStack(alignment: .center, spacing: Space.xl) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", average))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Brand.ink)
                StarRow(rating: average, size: 12)
                Text(app.t("\(count) تقييم", "\(count) reviews"))
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.inkSoft)
            }
            VStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text("\(5 - i)").font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Brand.inkSoft).frame(width: 10)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Brand.bg2)
                                Capsule().fill(Brand.accent.opacity(0.85)).frame(width: geo.size.width * fraction(i))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private func fraction(_ i: Int) -> CGFloat {
        let total = max(distribution.reduce(0, +), 1)
        return CGFloat(distribution[i]) / CGFloat(total)
    }
}

struct ReviewCard: View {
    @EnvironmentObject var app: AppState
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                GradientMonogramAvatar(seed: review.nameEn,
                                       initials: String(app.t(review.nameAr, review.nameEn).prefix(1)),
                                       size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t(review.nameAr, review.nameEn))
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink)
                    StarRow(rating: Double(review.rating), size: 10)
                }
                Spacer(minLength: 0)
            }
            Text(app.t(review.textAr, review.textEn))
                .font(.system(size: 14, design: .rounded)).foregroundStyle(Brand.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .frame(width: 270, alignment: .leading)
        .softCard()
    }
}

// MARK: - Duration segmented control

struct DurationSegment: View {
    @EnvironmentObject var app: AppState
    let options: [Int]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { minutes in
                let sel = selection == minutes
                Button {
                    Haptics.tap()
                    withAnimation(Motion.spring) { selection = minutes }
                } label: {
                    Text(app.t("\(minutes) د", "\(minutes) min"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(sel ? AnyShapeStyle(Brand.brandGradient) : AnyShapeStyle(Brand.paper))
                        .foregroundStyle(sel ? Brand.paper : Brand.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                .stroke(Brand.bg2, lineWidth: sel ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
