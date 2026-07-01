import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    ForEach(Catalog.all) { m in
                        NavigationLink(value: m) { MassageCard(massage: m) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("massage-\(m.id)")
                    }
                    trust
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
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
                        .font(.headline)
                        .foregroundStyle(Brand.pinkDeep)
                }
            }
            .navigationDestination(for: Massage.self) { m in
                MassageDetailView(massage: m)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.t("السبا يجيكِ البيت", "The spa comes home"))
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Brand.pink)
            Text(app.t("مساج احترافي نسائي، في بيتكِ بجدة",
                       "Professional women-only massage, at your home in Jeddah"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(app.t("معالِجات معتمدات · نساء فقط · أدوات معقّمة",
                       "Certified therapists · Women only · Sealed tools"))
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Brand.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 8)
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
