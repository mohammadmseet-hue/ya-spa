import SwiftUI

/// Therapist profile: monogram identity, verified badge, specialty, bio, and reviews.
/// Purely additive — reached from the "Meet your therapists" rows on a service detail.
struct TherapistProfileView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var data: DataStore
    let therapist: Therapist

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                header
                specialties
                bioCard
                reviewsBlock
            }
            .padding(Space.screen)
            .padding(.bottom, Space.huge)
        }
        .background(AmbientBackground())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: Space.m) {
            GradientMonogramAvatar(seed: therapist.id,
                                   initials: String(app.t(therapist.nameAr, therapist.nameEn).prefix(1)),
                                   size: 88, verified: true)
            Text(app.t(therapist.nameAr, therapist.nameEn))
                .spaFont(.serviceName, ar: app.isAr).foregroundStyle(Brand.ink)
            HStack(spacing: 6) {
                StarRow(rating: therapist.rating, size: 13)
                Text("\(String(format: "%.2f", therapist.rating)) · \(therapist.reviews) \(app.t("تقييم", "reviews"))")
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
            }
            HStack(spacing: Space.s) {
                badge("checkmark.seal.fill", app.t("موثّقة · أنثى", "Verified · Female"))
                badge("clock", app.t("\(therapist.years) سنوات خبرة", "\(therapist.years) yrs"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }

    private func badge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.rubik(12, .semibold))
        }
        .foregroundStyle(Brand.pinkDeep)
        .padding(.vertical, 7).padding(.horizontal, 12)
        .overlay(Capsule().stroke(Brand.gold.opacity(0.4), lineWidth: 1))
    }

    private var specialties: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("التخصص", "Specialty"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            HStack {
                BenefitChip(text: app.t(therapist.specialtyAr, therapist.specialtyEn))
                Spacer(minLength: 0)
            }
        }
    }

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("نبذة", "About"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t(therapist.bioAr, therapist.bioEn))
                .font(.rubik(15)).foregroundStyle(Brand.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .softCard()
    }

    private var reviewsBlock: some View {
        ReviewsSection(average: therapist.rating, count: therapist.reviews,
                       distribution: [therapist.reviews * 88 / 100,
                                      therapist.reviews * 9 / 100,
                                      therapist.reviews * 2 / 100,
                                      therapist.reviews * 1 / 100, 0],
                       reviews: data.reviews)
    }
}
