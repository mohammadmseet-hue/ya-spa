import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Brand.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct MassageCard: View {
    @EnvironmentObject var app: AppState
    let massage: Massage

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Brand.bg2)
                Image(systemName: massage.symbol)
                    .font(.title2)
                    .foregroundStyle(Brand.pinkDeep)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.t(massage.nameAr, massage.nameEn))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Brand.ink)
                Text(app.t("\(massage.minutes) دقيقة", "\(massage.minutes) min"))
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(app.money(massage.price))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.pinkDeep)
                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundStyle(Brand.muted)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Brand.pinkDeep.opacity(0.06), radius: 10, y: 4)
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
