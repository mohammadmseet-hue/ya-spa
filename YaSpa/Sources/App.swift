import SwiftUI

@main
struct YaSpaApp: App {
    @StateObject private var app = AppState()
    @StateObject private var store = BookingStore()
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.checking {
                    ZStack {
                        Brand.heroGradient.ignoresSafeArea()
                        ProgressView().tint(Brand.pinkDeep)
                    }
                } else if !Config.isConfigured || auth.isAuthenticated {
                    // Backend not connected yet → app works as-is (no login wall).
                    // Once Supabase keys are set, phone-auth is enforced.
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

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(app.t("المساج", "Massage"), systemImage: "sparkles") }
            MyBookingsView()
                .tabItem { Label(app.t("حجوزاتي", "My bookings"), systemImage: "calendar") }
        }
    }
}
