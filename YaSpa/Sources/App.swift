import SwiftUI

@main
struct YaSpaApp: App {
    @StateObject private var app = AppState()
    @StateObject private var store = BookingStore()
    @StateObject private var auth = AuthStore()
    @StateObject private var data = DataStore()
    @AppStorage("yaspa.onboarded") private var onboarded = false
    @AppStorage("yaspa.theme") private var theme = "light"   // light (default) | dusk

    private var scheme: ColorScheme? {
        // Always light by default; dusk is an explicit opt-in (never follow the device).
        return theme == "dusk" ? .dark : .light
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Root opaque floor: guarantees a warm brand backing behind every tab
                // switch / cover / transition, so a "black frame" is structurally
                // unreachable even if a screen's background is mid-layout.
                Brand.bg.ignoresSafeArea()

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
            }
            .environmentObject(app)
            .environmentObject(store)
            .environmentObject(auth)
            .environmentObject(data)
            .environment(\.layoutDirection, app.layout)
            .tint(Brand.pinkDeep)
            .preferredColorScheme(scheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @EnvironmentObject var data: DataStore
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
        // Never animate the tab container swap — TabView can't interpolate it and an
        // animated swap flashes a black frame on device.
        .animation(nil, value: tab)
        .task {
            // Load the live catalog from Supabase (falls back to built-in data),
            // then pull this user's bookings from the cloud (no-op until signed in).
            await data.refresh()
            store.merge(await CloudBookings.list())
        }
    }
}
