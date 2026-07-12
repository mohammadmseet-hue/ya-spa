import SwiftUI
import Supabase

/// The app's live catalog, loaded from Supabase. Starts with the built-in catalog so
/// screens render instantly and work offline, then refreshes from the backend — so the
/// business can change services / prices / therapists / reviews server-side and the app
/// updates with no new build. In UI tests it stays on the deterministic built-in data.
@MainActor
final class DataStore: ObservableObject {
    @Published var massages: [Massage] = Catalog.all
    @Published var therapists: [Therapist] = Therapists.all
    @Published var reviews: [Review] = Reviews.all
    @Published var loaded = false
    @Published var isAdmin = false          // true → the Owner console tab appears

    /// Ask the backend whether this user is an operator (drives the Owner tab).
    func checkAdmin() async {
        guard Config.isConfigured, !Runtime.isUITest else { isAdmin = false; return }
        isAdmin = await CloudBookings.isAdmin()
    }

    // MARK: Row mappings

    private struct ServiceRow: Decodable {
        let id: String
        let name_ar: String, name_en: String
        let desc_ar: String?, desc_en: String?
        let minutes: Int, price: Int
        let symbol: String?
        let pressure_ar: String?, pressure_en: String?
        let benefits_ar: [String]?, benefits_en: [String]?
        func toMassage() -> Massage {
            Massage(id: id, nameAr: name_ar, nameEn: name_en,
                    descAr: desc_ar ?? "", descEn: desc_en ?? "",
                    minutes: minutes, price: price, symbol: symbol ?? "sparkles",
                    pressureAr: pressure_ar ?? "متوسط", pressureEn: pressure_en ?? "Medium",
                    benefitsAr: benefits_ar ?? [], benefitsEn: benefits_en ?? [])
        }
    }

    private struct TherapistRow: Decodable {
        let id: String
        let name_ar: String, name_en: String
        let rating: Double
        let years: Int?, reviews: Int?
        let specialty_ar: String?, specialty_en: String?
        let bio_ar: String?, bio_en: String?
        func toTherapist() -> Therapist {
            Therapist(id: id, nameAr: name_ar, nameEn: name_en, rating: rating, years: years ?? 0,
                      reviews: reviews ?? 0, specialtyAr: specialty_ar ?? "", specialtyEn: specialty_en ?? "",
                      bioAr: bio_ar ?? "", bioEn: bio_en ?? "")
        }
    }

    private struct ReviewRow: Decodable {
        let name_ar: String?, name_en: String?
        let rating: Int
        let text_ar: String?, text_en: String?
        func toReview() -> Review {
            Review(nameAr: name_ar ?? "", nameEn: name_en ?? "", rating: rating,
                   textAr: text_ar ?? "", textEn: text_en ?? "")
        }
    }

    // MARK: Load

    func refresh() async {
        guard Config.isConfigured, !Runtime.isUITest else { return }

        // Fetch first, then swap in one animated transaction so the built-in catalog
        // cross-fades into the live data instead of hard-cutting mid-screen.
        var newMassages = massages, newTherapists = therapists, newReviews = reviews
        if let rows: [ServiceRow] = try? await SB.client.from("services")
            .select().eq("active", value: true).order("sort").execute().value, !rows.isEmpty {
            newMassages = rows.map { $0.toMassage() }
        }
        if let rows: [TherapistRow] = try? await SB.client.from("therapists")
            .select().eq("active", value: true).order("rating", ascending: false).execute().value, !rows.isEmpty {
            newTherapists = rows.map { $0.toTherapist() }
        }
        if let rows: [ReviewRow] = try? await SB.client.from("reviews")
            .select().order("created_at", ascending: false).execute().value, !rows.isEmpty {
            newReviews = rows.map { $0.toReview() }
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            massages = newMassages
            therapists = newTherapists
            reviews = newReviews
            loaded = true
        }
    }

    /// The real booked times for a therapist on a date (from the taken_slots RPC), so the
    /// booking grid can grey out slots that are actually taken. Empty in tests / offline.
    func takenSlots(therapist: String, date: String) async -> Set<String> {
        guard Config.isConfigured, !Runtime.isUITest else { return [] }
        struct Row: Decodable { let booking_time: String }
        do {
            let rows: [Row] = try await SB.client
                .rpc("taken_slots", params: ["p_therapist": therapist, "p_date": date])
                .execute().value
            return Set(rows.map { $0.booking_time })
        } catch {
            return []
        }
    }
}
