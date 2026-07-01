import SwiftUI

@main
struct YaSpaApp: App {
    @StateObject private var app = AppState()
    @StateObject private var store = BookingStore()
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if Config.requireAuth && auth.checking {
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

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(app.t("المساج", "Massage"), systemImage: "sparkles") }
            MyBookingsView()
                .tabItem { Label(app.t("حجوزاتي", "My bookings"), systemImage: "calendar") }
        }
    }
}
