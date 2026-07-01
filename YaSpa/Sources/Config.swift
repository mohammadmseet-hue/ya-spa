import Foundation

/// Backend config. The publishable/anon key is public-safe to ship — Row-Level
/// Security protects the data.
enum Config {
    static let supabaseURL     = "https://plzdjimvrvuhxnenrdgt.supabase.co"
    static let supabaseAnonKey = "sb_publishable_VI34RwrbHGU-UP-Dq6iyIQ_lsre1bGA"

    /// Backend is connected (cloud data + cloud bookings active).
    static var isConfigured: Bool {
        !supabaseURL.contains("REPLACE") && !supabaseAnonKey.contains("REPLACE")
    }

    /// Enforce the phone-login gate. Kept OFF until an SMS provider is configured in
    /// Supabase Auth, so the app is never stuck at a login it can't complete. Flip to
    /// true the moment SMS OTP works.
    static let requireAuth = false
}
