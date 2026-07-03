import SwiftUI

struct MassageDetailView: View {
    @EnvironmentObject var app: AppState
    let massage: Massage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                heroBand
                bestFor
                includedCard
                therapistPreview
                reviewsBlock
            }
            .padding(Space.screen)
            .padding(.bottom, Space.huge)
        }
        .background(AmbientBackground())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bookBar }
    }

    // MARK: Hero

    private var heroBand: some View {
        VStack(spacing: Space.m) {
            ArchMedallion(symbol: massage.symbol, width: 84, height: 104).padding(.top, Space.s)
            Text(app.t(massage.nameAr, massage.nameEn))
                .spaFont(.serviceName, ar: app.isAr)
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                StarRow(rating: 4.9, size: 12)
                Text(app.t("4.9 · 128 تقييم", "4.9 · 128 reviews"))
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
            }
            Text(app.t(massage.descAr, massage.descEn))
                .font(.rubik(15)).foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.l) {
                MetadataChip(icon: "clock", text: app.t("\(massage.minutes) دقيقة", "\(massage.minutes) min"))
                PressureIndicator(label: app.t(massage.pressureAr, massage.pressureEn),
                                  level: PressureIndicator.level(for: massage.pressureEn))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.xl)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Brand.heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Brand.paper.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Brand.shadowBloom.opacity(0.1), radius: 24, y: 12)
    }

    // MARK: Best for

    private var bestFor: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("مناسب لـ", "Best for"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(app.isAr ? massage.benefitsAr : massage.benefitsEn, id: \.self) { b in
                        BenefitChip(text: b)
                    }
                }
            }
        }
    }

    // MARK: Included

    private var includedCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("ما تشمله الجلسة", "What's included"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            infoRow(app.t("معالِجة معتمدة — نساء فقط", "A certified woman therapist — women only"))
            infoRow(app.t("أدوات معقّمة لمرّة واحدة، تُفتح أمامكِ", "Sealed, single-use tools opened before you"))
            infoRow(app.t("أغطية نظيفة وزيوت معتمدة من الهيئة", "Fresh linens & SFDA-approved oils"))
            infoRow(app.t("أغطية تحفظ خصوصيتكِ طوال الجلسة", "Draping that protects your privacy"))
            infoRow(app.t("السعر يشمل المواصلات وضريبة ١٥٪", "Price includes transport & 15% VAT"))
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }

    private func infoRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.pink)
            Text(text).font(.rubik(15)).foregroundStyle(Brand.ink)
            Spacer(minLength: 0)
        }
    }

    // MARK: Therapists

    private var therapistPreview: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("معالِجاتكِ", "Meet your therapists"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            VStack(spacing: Space.s) {
                ForEach(Therapists.all.prefix(2)) { th in
                    NavigationLink(value: th) {
                        HStack(spacing: Space.m) {
                            GradientMonogramAvatar(seed: th.id,
                                                   initials: String(app.t(th.nameAr, th.nameEn).prefix(1)),
                                                   size: 46, verified: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.t(th.nameAr, th.nameEn))
                                    .font(.rubik(15, .semibold)).foregroundStyle(Brand.ink)
                                Text(app.t(th.specialtyAr, th.specialtyEn))
                                    .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
                            }
                            Spacer(minLength: 0)
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Brand.gold)
                                Text(String(format: "%.2f", th.rating))
                                    .font(.rubik(13, .semibold)).foregroundStyle(Brand.ink)
                            }
                            Image(systemName: "chevron.forward").font(.caption2).foregroundStyle(Brand.inkSoft)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("therapist-profile-\(th.id)")
                }
            }
            .padding(Space.l)
            .softCard()
        }
    }

    // MARK: Reviews

    private var reviewsBlock: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("التقييمات", "Reviews"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            RatingSummary(average: 4.9, count: 128, distribution: [112, 12, 3, 1, 0])
                .padding(Space.l).softCard()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(Reviews.all) { ReviewCard(review: $0) }
                }
            }
        }
    }

    // MARK: Book bar

    private var bookBar: some View {
        StickyGlassBar {
            HStack(spacing: Space.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t("الإجمالي", "Total"))
                        .font(.rubik(11)).foregroundStyle(Brand.inkSoft)
                    Text(app.money(Pricing.total(massage.price)))
                        .spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
                }
                NavigationLink {
                    BookingView(massage: massage)
                } label: {
                    Text(app.t("احجزي الآن", "Book now"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("book-session")
            }
        }
    }
}
