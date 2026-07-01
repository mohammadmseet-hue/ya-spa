import SwiftUI

/// Account / profile tab: who's signed in, quick stats, language preference,
/// and about. Auth-aware — shows the phone + Sign out once phone login is live,
/// a friendly guest state until then.
struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountCard
                    preferences
                    about
                    footer
                }
                .padding(16)
            }
            .background(Brand.bg.ignoresSafeArea())
            .navigationTitle(app.t("حسابي", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var accountCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Brand.heroGradient).frame(width: 74, height: 74)
                Image(systemName: "person.fill").font(.title).foregroundStyle(Brand.pinkDeep)
            }
            if auth.isAuthenticated && !auth.e164Phone.isEmpty {
                Text(auth.e164Phone).font(.headline).foregroundStyle(Brand.ink)
                Text(app.t("مسجّلة الدخول", "Signed in"))
                    .font(.caption).foregroundStyle(Brand.muted)
            } else {
                Text(app.t("زائرة", "Guest")).font(.headline).foregroundStyle(Brand.ink)
                Text(app.t("حجوزاتكِ محفوظة على هذا الجهاز",
                           "Your bookings are saved on this device"))
                    .font(.caption).foregroundStyle(Brand.muted).multilineTextAlignment(.center)
            }

            stat("\(store.bookings.count)", app.t("حجوزات", "Bookings"))
                .padding(.top, 2)

            if auth.isAuthenticated {
                Button { Task { await auth.signOut() } } label: {
                    Text(app.t("تسجيل الخروج", "Sign out")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Brand.pinkDeep)
                .accessibilityIdentifier("sign-out")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Brand.pinkDeep)
            Text(label).font(.caption2).foregroundStyle(Brand.muted)
        }
    }

    private var preferences: some View {
        row(icon: "globe", title: app.t("اللغة", "Language"),
            value: app.isAr ? "العربية" : "English") { app.toggle() }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(icon: String, title: String, value: String,
                     action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Brand.pinkDeep).frame(width: 26)
                Text(title).foregroundStyle(Brand.ink)
                Spacer()
                Text(value).foregroundStyle(Brand.muted)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.muted.opacity(0.5))
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-language")
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.t("عن يا سبا", "About Ya Spa"))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            Text(app.t("مساج احترافي للنساء فقط، يجيكِ البيت في جدة. معالِجات معتمدات وأدوات معقّمة.",
                       "Professional women-only massage, brought to your home in Jeddah. Certified therapists and sealed, sanitized tools."))
                .font(.footnote).foregroundStyle(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TrustChip(icon: "person.fill", text: app.t("نساء فقط", "Women only"))
                TrustChip(icon: "checkmark.seal.fill", text: app.t("معتمدة", "Certified"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        Text("Ya Spa · v1.0")
            .font(.caption2).foregroundStyle(Brand.muted.opacity(0.7))
            .padding(.top, 4)
    }
}
