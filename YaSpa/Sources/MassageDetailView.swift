import SwiftUI

struct MassageDetailView: View {
    @EnvironmentObject var app: AppState
    let massage: Massage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Brand.heroGradient)
                        .frame(height: 180)
                    Image(systemName: massage.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(Brand.pinkDeep)
                }

                Text(app.t(massage.nameAr, massage.nameEn))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.ink)

                HStack(spacing: 10) {
                    Pill(text: app.t("\(massage.minutes) دقيقة", "\(massage.minutes) min"), icon: "clock")
                    Pill(text: app.money(massage.price), icon: "tag")
                }

                Text(app.t(massage.descAr, massage.descEn))
                    .font(.body)
                    .foregroundStyle(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    infoRow(app.t("نساء فقط، معالِجات معتمدات", "Women only, certified therapists"))
                    infoRow(app.t("أدوات وأغطية معقّمة تُفتح أمامكِ", "Sealed tools & linens, opened before you"))
                    infoRow(app.t("السعر يشمل المواصلات والضريبة", "Price includes transport & VAT"))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Brand.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                BookingView(massage: massage)
            } label: {
                Text(app.t("احجزي هذه الجلسة", "Book this session"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("book-session")
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }

    private func infoRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.pink)
            Text(text).font(.subheadline).foregroundStyle(Brand.ink)
            Spacer(minLength: 0)
        }
    }
}
