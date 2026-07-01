import Foundation

/// Backend config. Filled in once the Supabase project exists.
/// The anon key is public-safe to ship — Row-Level Security protects the data.
enum Config {
    static let supabaseURL     = "https://REPLACE.supabase.co"
    static let supabaseAnonKey = "REPLACE_ANON_KEY"

    /// Whether real backend credentials have been set (vs. the placeholders).
    static var isConfigured: Bool {
        !supabaseURL.contains("REPLACE") && !supabaseAnonKey.contains("REPLACE")
    }
}
