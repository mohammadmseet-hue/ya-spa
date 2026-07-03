import SwiftUI

/// The app's home/landing dashboard as a command center: greeting, your next booking
/// (or a first-book CTA), the Ya Spa promise, service tiles, and social proof.
struct HomeDashboardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var goToMassage: () -> Void

    @State private var breathe = false
    private let cols = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    greeting
                    if let next = store.bookings.first { upcomingCard(next) } else { firstBookCTA }
                    promiseSection
                    JasmineDivider().padding(.vertical, Space.xs)
                    servicesGrid
                    reviewsRail
                }
                .padding(Space.screen)
                .padding(.bottom, Space.huge)
            }
            .background(AmbientBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    YaSpaWordmark(compact: true)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline).foregroundStyle(Brand.accent)
                        .accessibilityIdentifier("lang-home")
                }
            }
        }
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("نساء فقط · بجدة", "WOMEN ONLY · JEDDAH"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(app.isAr ? 0 : 1.8).foregroundStyle(Brand.inkSoft)
                Rectangle().fill(Brand.gold.opacity(0.6)).frame(width: 100, height: 1)
                Text(app.t("أهلًا بكِ 🌸", "Welcome 🌸"))
                    .spaFont(.display, ar: app.isAr).foregroundStyle(Brand.ink)
                Text(app.t("السبا يجيكِ البيت", "Your spa, at home"))
                    .font(.system(size: 15, design: .rounded)).foregroundStyle(Brand.inkSoft)
            }
            Spacer(minLength: 0)
            ArchMedallion(symbol: "sparkles", width: 56, height: 70)
                .scaleEffect(breathe ? 1.04 : 1)
                .animation((reduceMotion || Runtime.isUITest) ? nil
                           : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
                .onAppear { if !reduceMotion && !Runtime.isUITest { breathe = true } }
        }
        .padding(.top, Space.s)
    }

    private func upcomingCard(_ b: Booking) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("حجزكِ القادم", "Your next booking"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            HStack(spacing: Space.m) {
                GradientMonogramAvatar(seed: b.therapistName,
                                       initials: String(b.therapistName.prefix(1)),
                                       size: 50, verified: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.t(b.massageNameAr, b.massageNameEn))
                        .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                    Text("\(b.dateISO) · \(b.time)")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(Brand.inkSoft)
                    Text(b.therapistName)
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.inkSoft)
                }
                Spacer(minLength: 0)
                Text(app.money(Pricing.total(b.price)))
                    .spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
            }
            .padding(Space.l).softCard()
            bookButton
        }
    }

    private var firstBookCTA: some View {
        VStack(spacing: Space.l) {
            ArchMedallion(symbol: "sparkles", width: 70, height: 88)
            Text(app.t("جاهزة للاسترخاء؟", "Ready to relax?"))
                .spaFont(.serviceName, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t("احجزي أول جلسة مساج، وتجيكِ المعالِجة إلى البيت.",
                       "Book your first massage — your therapist comes to you."))
                .font(.system(size: 15, design: .rounded)).foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
            bookButton
        }
        .frame(maxWidth: .infinity)
        .padding(Space.xl)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Brand.heroGradient))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Brand.paper.opacity(0.5), lineWidth: 1))
    }

    private var bookButton: some View {
        Button {
            Haptics.tap()
            // One finite, owned spring for the switch — nothing to leak into.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { goToMassage() }
        } label: {
            Label(app.t("احجزي جلسة مساج", "Book a massage"), systemImage: "plus.circle.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("dashboard-book")
    }

    private var promiseSection: some View {
        VStack(spacing: Space.m) {
            PromiseStrip()
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Brand.gold).font(.system(size: 13))
                Text(app.t("4.9 · أكثر من 12,000 جلسة", "4.9 ★ · 12,000+ sessions"))
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Brand.inkSoft)
            }
        }
    }

    private var servicesGrid: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("خدماتنا", "Our services"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            LazyVGrid(columns: cols, spacing: Space.m) {
                ForEach(Catalog.all) { m in
                    Button { Haptics.tap(); goToMassage() } label: { serviceTile(m) }
                        .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    private func serviceTile(_ m: Massage) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ArchMedallion(symbol: m.symbol, width: 44, height: 56)
            Text(app.t(m.nameAr, m.nameEn))
                .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Brand.ink).lineLimit(1)
            HStack {
                Text(app.t("\(m.minutes) د", "\(m.minutes) min"))
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.inkSoft)
                Spacer()
                Text(app.money(m.price))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Brand.pinkDeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .softCard()
    }

    private var reviewsRail: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("آراء عميلاتنا", "What women say"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(Reviews.all) { ReviewCard(review: $0) }
                }
            }
        }
    }
}
