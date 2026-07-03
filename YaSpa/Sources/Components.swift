import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Brand.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .shadow(color: Brand.shadowBloom.opacity(0.28), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in if pressed { Haptics.tap() } }
    }
}

/// The rich catalog card carrying all four decision-drivers:
/// medallion · serif name · benefit · (duration · rating · pressure) · price.
struct MassageCard: View {
    @EnvironmentObject var app: AppState
    let massage: Massage

    var body: some View {
        HStack(spacing: Space.l) {
            SFSymbolMedallion(symbol: massage.symbol, size: 58, rounded: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.t(massage.nameAr, massage.nameEn))
                    .spaFont(.cardTitle, ar: app.isAr)
                    .foregroundStyle(Brand.ink)
                Text(app.t(massage.benefitsAr.first ?? "", massage.benefitsEn.first ?? ""))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Brand.inkSoft).lineLimit(1)
                HStack(spacing: 10) {
                    MetadataChip(icon: "clock", text: app.t("\(massage.minutes) د", "\(massage.minutes) min"))
                    MetadataChip(icon: "star.fill", text: "4.9")
                    PressureIndicator(label: app.t(massage.pressureAr, massage.pressureEn),
                                      level: PressureIndicator.level(for: massage.pressureEn))
                }
            }

            Spacer(minLength: Space.s)

            VStack(alignment: .trailing, spacing: 8) {
                Text(app.money(massage.price))
                    .spaFont(.price, ar: app.isAr)
                    .foregroundStyle(Brand.pinkDeep)
                Image(systemName: "chevron.forward")
                    .font(.caption2).foregroundStyle(Brand.inkSoft)
            }
        }
        .padding(Space.l)
        .softCard()
    }
}

struct TrustChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption2).fontWeight(.medium)
        }
        .foregroundStyle(Brand.pinkDeep)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(Capsule())
    }
}

struct Pill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption).fontWeight(.semibold)
        }
        .foregroundStyle(Brand.pinkDeep)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(Brand.bg2)
        .clipShape(Capsule())
    }
}
