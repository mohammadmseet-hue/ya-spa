import SwiftUI

/// The app's home/landing dashboard: greeting, next booking, a big "book" CTA,
/// popular picks, and trust — the front door of the app.
struct HomeDashboardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    var goToMassage: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    if let next = store.bookings.first { upcoming(next) }
                    bookButton
                    popular
                    trust
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Brand.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(app.t("يا سبا", "Ya Spa"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Brand.pinkDeep)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline).foregroundStyle(Brand.pinkDeep)
                        .accessibilityIdentifier("lang-home")
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(app.t("أهلًا بكِ 🌸", "Welcome 🌸"))
                .font(.caption).fontWeight(.semibold).foregroundStyle(Brand.pink)
            Text(app.t("المساج النسائي يجيكِ البيت", "Women's massage, at your home"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(app.t("معالِجات معتمدات · نساء فقط · بجدة",
                       "Certified therapists · Women only · Jeddah"))
                .font(.subheadline).foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 8)
    }

    private func upcoming(_ b: Booking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(app.t("حجزكِ القادم", "Your next booking"))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2).foregroundStyle(Brand.pinkDeep)
                    .frame(width: 46, height: 46).background(Brand.bg2).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t(b.massageNameAr, b.massageNameEn))
                        .font(.headline).foregroundStyle(Brand.ink)
                    Text("\(b.dateISO) · \(b.time) · \(b.therapistName)")
                        .font(.caption).foregroundStyle(Brand.muted)
                }
                Spacer(minLength: 0)
                Text(app.money(Pricing.total(b.price)))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.pinkDeep)
            }
            .padding(14).background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var bookButton: some View {
        Button {
            Haptics.tap(); goToMassage()
        } label: {
            Label(app.t("احجزي جلسة مساج", "Book a massage"), systemImage: "plus.circle.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("dashboard-book")
    }

    private var popular: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.t("الأكثر طلبًا", "Popular")).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(Catalog.all.prefix(4))) { m in
                        Button { goToMassage() } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: m.symbol).font(.title2).foregroundStyle(Brand.pinkDeep)
                                Text(app.t(m.nameAr, m.nameEn))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink).lineLimit(1)
                                Text(app.money(m.price)).font(.caption).foregroundStyle(Brand.muted)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(14).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var trust: some View {
        HStack(spacing: 10) {
            TrustChip(icon: "checkmark.seal.fill", text: app.t("موثّقات", "Verified"))
            TrustChip(icon: "person.fill", text: app.t("نساء فقط", "Women only"))
            TrustChip(icon: "sparkles", text: app.t("معقّمة", "Sealed"))
        }
        .padding(.top, 4)
    }
}
