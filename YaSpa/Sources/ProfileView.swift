import SwiftUI

/// Account / profile tab: who's signed in, quick stats, preferences, and about.
struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @EnvironmentObject var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @AppStorage("yaspa.theme") private var theme = "system"

    private var themeLabel: String {
        switch theme {
        case "light": return app.t("فاتح", "Light")
        case "dusk":  return app.t("داكن", "Dusk")
        default:      return app.t("تلقائي", "System")
        }
    }
    private func cycleTheme() {
        theme = theme == "system" ? "light" : (theme == "light" ? "dusk" : "system")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    accountCard
                    preferences
                    PromiseStrip()
                    about
                    footer
                }
                .padding(Space.screen)
                .padding(.bottom, Space.xl)
            }
            .background(AmbientBackground())
            .navigationTitle(app.t("حسابي", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var accountCard: some View {
        VStack(spacing: Space.m) {
            SFSymbolMedallion(symbol: "person.fill", size: 74)
            if auth.isAuthenticated && !auth.e164Phone.isEmpty {
                Text(auth.e164Phone).spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                Text(app.t("مسجّلة الدخول", "Signed in"))
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
            } else {
                Text(app.t("زائرة", "Guest")).spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                Text(app.t("حجوزاتكِ محفوظة على هذا الجهاز", "Your bookings are saved on this device"))
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
                    .multilineTextAlignment(.center)
            }

            stat("\(store.bookings.count)", app.t("حجوزات", "Bookings")).padding(.top, 2)

            if auth.isAuthenticated {
                Button { Task { await auth.signOut() } } label: {
                    Text(app.t("تسجيل الخروج", "Sign out")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Brand.pinkDeep)
                .accessibilityIdentifier("sign-out")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.xl)
        .softCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.rubik(22, .bold)).foregroundStyle(Brand.pinkDeep)
            Text(label).font(.rubik(11, .medium)).foregroundStyle(Brand.inkSoft)
        }
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            row(icon: "globe", title: app.t("اللغة", "Language"),
                value: app.isAr ? "العربية" : "English",
                id: "profile-language") { app.toggle() }
            Divider().padding(.leading, 52)
            row(icon: "moon.stars.fill", title: app.t("المظهر", "Theme"),
                value: themeLabel, id: "profile-theme") { cycleTheme() }
            Divider().padding(.leading, 52)
            row(icon: "message.fill", title: app.t("تواصلي معنا", "Contact us"),
                value: "WhatsApp", id: "profile-contact") {
                openURL(URL(string: "https://wa.me/966565722923")!)
            }
        }
        .softCard()
    }

    private func row(icon: String, title: String, value: String,
                     id: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: Space.m) {
                Image(systemName: icon).foregroundStyle(Brand.pinkDeep).frame(width: 26)
                Text(title).font(.rubik(16)).foregroundStyle(Brand.ink)
                Spacer()
                Text(value).font(.rubik(15)).foregroundStyle(Brand.inkSoft)
                Image(systemName: "chevron.forward").font(.caption).foregroundStyle(Brand.inkSoft.opacity(0.5))
            }
            .padding(Space.l)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("عن يا سبا", "About Ya Spa"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t("مساج احترافي للنساء فقط، يجيكِ البيت في جدة. معالِجات معتمدات وأدوات معقّمة.",
                       "Professional women-only massage, brought to your home in Jeddah. Certified therapists and sealed, sanitized tools."))
                .font(.rubik(14)).foregroundStyle(Brand.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .softCard()
    }

    private var footer: some View {
        Text("Ya Spa · v1.0")
            .font(.rubik(11)).foregroundStyle(Brand.inkSoft.opacity(0.7))
            .padding(.top, Space.xs)
    }
}
