import SwiftUI
import Supabase

@MainActor
final class AuthStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var checking = true
    @Published var sending = false
    @Published var verifying = false
    @Published var codeSent = false
    @Published var errorMessage: String?

    private(set) var e164Phone = ""

    init() {
        if Runtime.isUITest {           // UI tests skip auth and go straight to the app
            isAuthenticated = true
            checking = false
            return
        }
        Task { await restore() }
    }

    /// Restore an existing session on launch.
    func restore() async {
        checking = true
        guard Config.isConfigured else { isAuthenticated = false; checking = false; return }
        do {
            _ = try await SB.client.auth.session
            isAuthenticated = true
        } catch {
            // No existing session → sign in anonymously so every device gets a real,
            // persistent identity and bookings actually persist under RLS. Requires
            // "Anonymous Sign-Ins" enabled in Supabase; if it isn't, the cloud simply
            // stays dormant and the app still works fully on-device.
            if !Runtime.isUITest {
                do {
                    try await SB.client.auth.signInAnonymously()
                    isAuthenticated = true
                } catch {
                    isAuthenticated = false
                }
            } else {
                isAuthenticated = false
            }
        }
        checking = false
    }

    /// Normalize a Saudi number to E.164 (+9665XXXXXXXX).
    static func normalize(_ raw: String) -> String {
        var d = raw.filter(\.isNumber)
        if d.hasPrefix("966") { return "+" + d }
        if d.hasPrefix("0") { d.removeFirst() }
        return "+966" + d
    }

    func sendOTP(phone raw: String) async {
        errorMessage = nil
        guard Config.isConfigured else { errorMessage = "Backend not connected yet."; return }
        e164Phone = Self.normalize(raw)
        sending = true
        do {
            try await SB.client.auth.signInWithOTP(phone: e164Phone)
            codeSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        sending = false
    }

    func verify(code: String) async {
        errorMessage = nil
        guard Config.isConfigured else { return }
        verifying = true
        do {
            try await SB.client.auth.verifyOTP(phone: e164Phone, token: code, type: .sms)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        verifying = false
    }

    func signOut() async {
        try? await SB.client.auth.signOut()
        isAuthenticated = false
        codeSent = false
    }
}
