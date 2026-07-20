import Foundation
import Supabase

/// Single shared Supabase client for the whole app.
enum SB {
    static let client: SupabaseClient = {
        let url = URL(string: Config.supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!

        // Bound every network call. The SDK routes BOTH auth (anonymous sign-in / token
        // refresh) AND every PostgREST RPC through this one URLSession, so these timeouts
        // cap the whole booking path. Without them the client falls back to URLSession.shared,
        // whose `timeoutIntervalForResource` defaults to 7 DAYS — a single stalled connection
        // (flaky cellular, captive portal, server mid-restart) would leave the "Book" button
        // spinning effectively forever. Fail fast instead so the UI can surface a real error.
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 12   // per-request stall cap (resets on data activity)
        cfg.timeoutIntervalForResource = 20   // hard ceiling for one request end-to-end
        cfg.waitsForConnectivity = false      // offline → error now, don't park the request
        let session = URLSession(configuration: cfg)

        let options = SupabaseClientOptions(global: .init(session: session))
        return SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey, options: options)
    }()
}
