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
                    Text(app.t("ما يشمله", "What's included"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Brand.ink)
                    infoRow(app.t("معالِجة معتمدة — نساء فقط", "A certified woman therapist — women only"))
                    infoRow(app.t("أدوات معقّمة لمرّة واحدة، تُفتح أمامكِ", "Sealed, single-use tools opened before you"))
                    infoRow(app.t("أغطية نظيفة وزيوت معتمدة من الهيئة", "Fresh linens & SFDA-approved oils"))
                    infoRow(app.t("أغطية تحفظ خصوصيتكِ طوال الجلسة", "Draping that protects your privacy"))
                    infoRow(app.t("السعر يشمل المواصلات وضريبة ١٥٪", "Price includes transport & 15% VAT"))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
