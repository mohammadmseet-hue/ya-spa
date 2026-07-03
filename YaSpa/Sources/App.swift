import SwiftUI

@main
struct YaSpaApp: App {
    @StateObject private var app = AppState()
    @StateObject private var store = BookingStore()
    @StateObject private var auth = AuthStore()
    @AppStorage("yaspa.onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboarded && !Runtime.isUITest {
                    OnboardingView { withAnimation(.easeInOut) { onboarded = true } }
                } else if Config.requireAuth && auth.checking {
                    ZStack {
                        Brand.heroGradient.ignoresSafeArea()
                        ProgressView().tint(Brand.pinkDeep)
                    }
                } else if !Config.requireAuth || auth.isAuthenticated {
                    // Login is enforced only once an SMS provider is live (Config.requireAuth).
                    RootView()
                } else {
                    AuthFlowView()
                }
            }
            .environmentObject(app)
            .environmentObject(store)
            .environmentObject(auth)
            .environment(\.layoutDirection, app.layout)
            .tint(Brand.pinkDeep)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeDashboardView(goToMassage: { tab = 1 })
                .tabItem { Label(app.t("الرئيسية", "Home"), systemImage: "house.fill") }
                .tag(0)
            HomeView()
                .tabItem { Label(app.t("المساج", "Massage"), systemImage: "sparkles") }
                .tag(1)
            MyBookingsView()
                .tabItem { Label(app.t("حجوزاتي", "My bookings"), systemImage: "calendar") }
                .tag(2)
            ProfileView()
                .tabItem { Label(app.t("حسابي", "Profile"), systemImage: "person.crop.circle") }
                .tag(3)
        }
        .task {
            // Pull this user's bookings from the cloud (no-op until signed in).
            store.merge(await CloudBookings.list())
        }
    }
}
