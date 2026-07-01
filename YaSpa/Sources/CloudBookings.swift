import Foundation
import Supabase

/// Persists a booking to the Supabase `bookings` table (cloud), so bookings live on
/// the backend and not just on-device. Dormant (no-op) until the backend is connected
/// and a user is signed in — then every booking is written to Postgres under RLS.
enum CloudBookings {
    private struct Row: Encodable {
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

    static func save(_ b: Booking) async {
        guard Config.isConfigured else { return }
        do {
            let uid = try await SB.client.auth.session.user.id
            let row = Row(
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
}
