import SwiftUI

@main
struct YaSpaApp: App {
    @StateObject private var app = AppState()
    @StateObject private var store = BookingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(store)
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
