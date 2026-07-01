import Foundation
import Supabase

/// Single shared Supabase client for the whole app.
enum SB {
    static let client: SupabaseClient = {
        let url = URL(string: Config.supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!
        return SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
    }()
}
