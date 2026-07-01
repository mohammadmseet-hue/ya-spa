import Foundation
import Supabase

/// Persists a booking to the Supabase `bookings` table (cloud), so bookings live on
/// the backend and not just on-device. Dormant (no-op) until the backend is connected
/// and a user is signed in — then every booking is written to Postgres under RLS.
enum CloudBookings {
    private struct Row: Encodable {
        let id: String
        let user_id: String
        let service_id: String
        let service_name_ar: String
        let service_name_en: String
        let minutes: Int
        let price: Int
        let therapist_name: String
        let booking_date: String
        let booking_time: String
        let district: String
        let notes: String
        let transport: Int
        let vat: Int
        let total: Int
    }

    /// One booking as returned from Postgres (only the columns we map back).
    private struct FetchRow: Decodable {
        let id: UUID
        let service_id: String?
        let service_name_ar: String?
        let service_name_en: String?
        let minutes: Int?
        let price: Int?
        let therapist_name: String?
        let booking_date: String
        let booking_time: String
        let district: String?
        let notes: String?

        func toBooking() -> Booking {
            Booking(
                id: id,
                massageId: service_id ?? "",
                massageNameAr: service_name_ar ?? "",
                massageNameEn: service_name_en ?? "",
                minutes: minutes ?? 60,
                price: price ?? 0,
                dateISO: booking_date,
                time: booking_time,
                therapistName: therapist_name ?? "",
                name: "",
                district: district ?? "",
                notes: notes ?? "",
                paymentMethod: nil
            )
        }
    }

    static func save(_ b: Booking) async {
        guard Config.isConfigured else { return }
        do {
            let uid = try await SB.client.auth.session.user.id
            let row = Row(
                id: b.id.uuidString,          // send the local id so cloud + device dedup cleanly
                user_id: uid.uuidString,
                service_id: b.massageId,
                service_name_ar: b.massageNameAr,
                service_name_en: b.massageNameEn,
                minutes: b.minutes,
                price: b.price,
                therapist_name: b.therapistName,
                booking_date: b.dateISO,
                booking_time: b.time,
                district: b.district,
                notes: b.notes,
                transport: Pricing.transport,
                vat: Pricing.vat(b.price),
                total: Pricing.total(b.price)
            )
            try await SB.client.from("bookings").insert(row).execute()
        } catch {
            // Non-fatal: the booking is still saved on-device.
        }
    }

    /// Fetch this user's bookings from the cloud. Returns [] when not signed in
    /// (RLS + no session), so it's a safe no-op until phone login is live.
    static func list() async -> [Booking] {
        guard Config.isConfigured else { return [] }
        do {
            _ = try await SB.client.auth.session   // require a session
            let rows: [FetchRow] = try await SB.client
                .from("bookings")
                .select("id,service_id,service_name_ar,service_name_en,minutes,price,therapist_name,booking_date,booking_time,district,notes")
                .order("booking_date", ascending: false)
                .execute()
                .value
            return rows.map { $0.toBooking() }
        } catch {
            return []
        }
    }
}
