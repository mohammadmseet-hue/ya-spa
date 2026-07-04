import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var data: DataStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    hero
                    ForEach(Array(data.massages.enumerated()), id: \.element.id) { idx, m in
                        NavigationLink(value: m) { MassageCard(massage: m) }
                            .buttonStyle(PressableCardStyle())
                            .accessibilityIdentifier("massage-\(m.id)")
                            .staggerAppear(idx)
                    }
                    PromiseStrip().padding(.top, Space.s)
                }
                .padding(.horizontal, Space.screen)
                .padding(.bottom, Space.huge)
            }
            .background(AmbientBackground())
            .refreshable { await data.refresh() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    YaSpaWordmark(compact: true)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline)
                        .foregroundStyle(Brand.accent)
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
                .font(.rubik(14))
                .foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.s)
    }
}
