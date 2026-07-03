import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rubik(16, .semibold))
            .foregroundStyle(Brand.ivory)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(configuration.isPressed ? Brand.accentPressed : Brand.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            // Antique-gold inset hairline — foil-stamp feel, not a glossy pill.
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .inset(by: 3)
                    .stroke(Brand.gold.opacity(0.35), lineWidth: 0.75)
            )
            .shadow(color: Brand.shadowRose.opacity(0.18), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
        HStack(spacing: Space.m) {
            ArchMedallion(symbol: massage.symbol, width: 50, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.t(massage.nameAr, massage.nameEn))
                    .spaFont(.cardTitle, ar: app.isAr)
                    .foregroundStyle(Brand.ink).lineLimit(1)
                Text(app.t(massage.benefitsAr.first ?? "", massage.benefitsEn.first ?? ""))
                    .font(.rubik(13))
                    .foregroundStyle(Brand.inkSoft).lineLimit(1)
                HStack(spacing: Space.s) {
                    MetadataChip(icon: "clock", text: app.t("\(massage.minutes) د", "\(massage.minutes) min"))
                    PressureIndicator(label: app.t(massage.pressureAr, massage.pressureEn),
                                      level: PressureIndicator.level(for: massage.pressureEn))
                    Spacer(minLength: Space.xs)
                    Text(app.money(massage.price))
                        .font(.system(size: 16, weight: .bold, design: app.isAr ? .rounded : .serif))
                        .foregroundStyle(Brand.pinkDeep).fixedSize()
                }
            }

            Image(systemName: "chevron.forward")
                .font(.caption2).foregroundStyle(Brand.inkSoft)
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
        .background(Brand.paper)
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
