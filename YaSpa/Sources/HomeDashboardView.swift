import SwiftUI

/// The app's home/landing dashboard as a command center: greeting, your next booking
/// (or a first-book CTA), the Ya Spa promise, service tiles, and social proof.
struct HomeDashboardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @EnvironmentObject var data: DataStore
    var goToMassage: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    greeting
                    if let next = store.bookings.first { upcomingCard(next) } else { firstBookCTA }
                    rebookRail
                    promiseSection
                    JasmineDivider().padding(.vertical, Space.xs)
                    servicesGrid
                    reviewsRail
                }
                .padding(Space.screen)
                .padding(.bottom, Space.huge)
            }
            .background(AmbientBackground())
            .refreshable { await data.refresh(); store.merge(await CloudBookings.list()) }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Massage.self) { MassageDetailView(massage: $0) }
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

    /// Recent distinct services the user has booked — one-tap to book again.
    private var recentServices: [Massage] {
        var seen = Set<String>(); var out: [Massage] = []
        for b in store.bookings where !seen.contains(b.massageId) {
            if let m = data.massages.first(where: { $0.id == b.massageId }) {
                seen.insert(b.massageId); out.append(m)
                if out.count == 5 { break }
            }
        }
        return out
    }

    @ViewBuilder private var rebookRail: some View {
        if !recentServices.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(app.t("احجزي مجددًا", "Book again"))
                    .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        ForEach(recentServices) { m in
                            NavigationLink(value: m) {
                                HStack(spacing: Space.s) {
                                    ArchMedallion(symbol: m.symbol, width: 34, height: 42)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.t(m.nameAr, m.nameEn))
                                            .font(.rubik(14, .semibold)).foregroundStyle(Brand.ink)
                                            .lineLimit(1).minimumScaleFactor(0.8)
                                        Text(app.money(m.price))
                                            .font(.rubik(12, .semibold)).foregroundStyle(Brand.pinkDeep)
                                    }
                                }
                                .frame(width: 180, alignment: .leading)
                                .padding(Space.m).softCard()
                            }
                            .buttonStyle(PressableCardStyle())
                            .accessibilityIdentifier("rebook-\(m.id)")
                        }
                    }
                }
            }
        }
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("نساء فقط · بجدة", "WOMEN ONLY · JEDDAH"))
                    .font(.rubik(12, .semibold))
                    .tracking(app.isAr ? 0 : 1.8).foregroundStyle(Brand.inkSoft)
                Rectangle().fill(Brand.gold.opacity(0.6)).frame(width: 100, height: 1)
                Text(app.t("أهلًا بكِ 🌸", "Welcome 🌸"))
                    .spaFont(.display, ar: app.isAr).foregroundStyle(Brand.ink)
                Text(app.t("السبا يجيكِ البيت", "Your spa, at home"))
                    .font(.rubik(15)).foregroundStyle(Brand.inkSoft)
            }
            Spacer(minLength: 0)
            ArchMedallion(symbol: "sparkles", width: 56, height: 70)
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
                        .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
                    Text(b.therapistName)
                        .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
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
                .font(.rubik(15)).foregroundStyle(Brand.inkSoft)
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
            // Instant tab switch — TabView selection must NOT be animated (animating it
            // glitches and can flash a black frame on device).
            goToMassage()
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
                    .font(.rubik(13, .medium)).foregroundStyle(Brand.inkSoft)
            }
        }
    }

    private var servicesGrid: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("خدماتنا", "Our services"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            // Editorial asymmetry: one featured card, then slim rows (no symmetric grid).
            if let first = data.massages.first {
                Button { Haptics.tap(); goToMassage() } label: { featureCard(first) }
                    .buttonStyle(PressableCardStyle())
            }
            ForEach(data.massages.dropFirst()) { m in
                Button { Haptics.tap(); goToMassage() } label: { slimRow(m) }
                    .buttonStyle(PressableCardStyle())
            }
        }
    }

    private func featureCard(_ m: Massage) -> some View {
        HStack(spacing: Space.l) {
            ArchMedallion(symbol: m.symbol, width: 60, height: 76)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.t("الأكثر طلبًا", "MOST LOVED"))
                    .font(.rubik(11, .semibold)).tracking(app.isAr ? 0 : 1.2).foregroundStyle(Brand.gold)
                Text(app.t(m.nameAr, m.nameEn))
                    .spaFont(.serviceName, ar: app.isAr).foregroundStyle(Brand.ink)
                    .lineLimit(2).minimumScaleFactor(0.9).allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Text(app.t(m.benefitsAr.first ?? "", m.benefitsEn.first ?? ""))
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(app.money(m.price)).spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep).fixedSize()
        }
        .padding(Space.l)
        .softCard().goldFrame()
    }

    private func slimRow(_ m: Massage) -> some View {
        HStack(spacing: Space.m) {
            ArchMedallion(symbol: m.symbol, width: 40, height: 50)
            Text(app.t(m.nameAr, m.nameEn))
                .font(.rubik(16, .semibold)).foregroundStyle(Brand.ink)
                .lineLimit(1).minimumScaleFactor(0.8).allowsTightening(true)
            Spacer(minLength: 0)
            Text(app.money(m.price)).font(.rubik(15, .semibold)).foregroundStyle(Brand.pinkDeep)
            Image(systemName: "chevron.forward").font(.caption2).foregroundStyle(Brand.inkSoft)
        }
        .padding(.vertical, Space.m).padding(.horizontal, Space.l)
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
