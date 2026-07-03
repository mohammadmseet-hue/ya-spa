import SwiftUI

/// First-run onboarding: three calm, branded intro pages that set the tone before
/// the app opens. Shown once (persisted via @AppStorage), and skipped in UI tests.
struct OnboardingView: View {
    @EnvironmentObject var app: AppState
    var done: () -> Void

    @State private var page = 0

    private struct Slide {
        let symbol: String
        let titleAr: String, titleEn: String
        let bodyAr: String, bodyEn: String
    }

    private let slides = [
        Slide(symbol: "leaf.fill",
              titleAr: "المساج النسائي يجيكِ البيت",
              titleEn: "Women's massage, at your home",
              bodyAr: "استرخاء احترافي بخصوصية تامة، في راحة بيتكِ بجدة.",
              bodyEn: "Professional relaxation in total privacy, at your home in Jeddah."),
        Slide(symbol: "checkmark.seal.fill",
              titleAr: "معالِجات معتمدات · نساء فقط",
              titleEn: "Certified therapists · women only",
              bodyAr: "معالِجات موثّقات، أدوات معقّمة تُفتح أمامكِ، وراحة بالكِ أولويتنا.",
              bodyEn: "Verified therapists, sealed tools opened before you, your comfort first."),
        Slide(symbol: "calendar.badge.checkmark",
              titleAr: "احجزي في ثوانٍ",
              titleEn: "Book in seconds",
              bodyAr: "اختاري المساج والوقت والمعالِجة، وادفعي عند الوصول.",
              bodyEn: "Pick your massage, time and therapist — pay on arrival."),
    ]

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline).foregroundStyle(Brand.pinkDeep)
                        .padding(.horizontal, 20).padding(.top, 8)
                }

                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        slideView(slides[i])
                            // Re-apply the real layout direction to each slide so Arabic
                            // text stays RTL while the PAGER geometry below is forced LTR.
                            .environment(\.layoutDirection, app.layout)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)
                // Pager progresses left→right (slide 1 leftmost); text direction is
                // restored per-slide above so this only affects paging geometry.
                .environment(\.layoutDirection, .leftToRight)

                dots.padding(.bottom, 20)

                Button {
                    Haptics.tap()
                    if page < slides.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
                    } else {
                        Haptics.success(); done()
                    }
                } label: {
                    Text(page < slides.count - 1
                         ? app.t("التالي", "Next")
                         : app.t("لنبدأ 🌸", "Get started 🌸"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)

                Button(app.t("تخطّي", "Skip")) { done() }
                    .font(.footnote).foregroundStyle(Brand.muted)
                    .padding(.top, 12).padding(.bottom, 8)
            }
            .frame(maxWidth: 480)
        }
    }

    private func slideView(_ s: Slide) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ArchMedallion(symbol: s.symbol, width: 132, height: 164)
                .shadow(color: Brand.shadowRose.opacity(0.12), radius: 22, y: 12)
            VStack(spacing: 12) {
                Text(app.t(s.titleAr, s.titleEn))
                    .spaFont(.display, ar: app.isAr)
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(app.t(s.bodyAr, s.bodyEn))
                    .font(.body).foregroundStyle(Brand.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Brand.accent : Brand.pinkSoft)
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
        .environment(\.layoutDirection, .leftToRight)   // match the LTR pager order
    }
}
