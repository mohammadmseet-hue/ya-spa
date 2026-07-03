import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    hero
                    ForEach(Catalog.all) { m in
                        NavigationLink(value: m) { MassageCard(massage: m) }
                            .buttonStyle(PressableCardStyle())
                            .accessibilityIdentifier("massage-\(m.id)")
                    }
                    PromiseStrip().padding(.top, Space.s)
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, Space.huge)
            }
            .background(AmbientBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(app.t("يا سبا", "Ya Spa"))
                        .font(.system(size: 20, weight: .semibold, design: app.isAr ? .rounded : .serif))
                        .foregroundStyle(Brand.pinkDeep)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline)
                        .foregroundStyle(Brand.pinkDeep)
                        .accessibilityIdentifier("lang-massage")
                }
            }
            .navigationDestination(for: Massage.self) { m in
                MassageDetailView(massage: m)
            }
            .navigationDestination(for: Therapist.self) { th in
                TherapistProfileView(therapist: th)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.t("جلسات المساج", "Massage menu"))
                .spaFont(.serviceName, ar: app.isAr)
                .foregroundStyle(Brand.ink)
            Text(app.t("اختاري جلستكِ · نساء فقط · بجدة",
                       "Choose your session · women only · Jeddah"))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.s)
    }
}
