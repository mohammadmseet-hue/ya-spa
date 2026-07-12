import Foundation
import Supabase

/// All order I/O goes through the server-authoritative RPCs (create_booking /
/// cancel_booking / admin_set_status). The client never writes price/status
/// directly — the backend computes and enforces them (see supabase/migrations).
enum CloudBookings {

    // MARK: - RPC params (keys must match the SQL argument names)

    private struct CreateParams: Encodable {
        let p_service_id: String
        let p_duration_min: Int
        let p_therapist_id: String
        let p_scheduled_at: String        // ISO8601 timestamptz, Asia/Riyadh
        let p_address_line: String
        let p_building: String
        let p_apartment: String
        let p_district: String
        let p_city: String
        let p_lat: Double?
        let p_lng: Double?
        let p_notes: String
        let p_payment_method: String
        let p_customer_name: String
        let p_contact_phone: String
    }
    private struct CancelParams: Encodable { let p_id: String }
    private struct StatusParams: Encodable { let p_id: String; let p_status: String }
    private struct NoArgs: Encodable {}

    /// Guarantee a session exists before any authed call, so a booking never
    /// races the launch-time anonymous sign-in (create_booking rejects a null
    /// auth.uid()). No-op if already signed in; silent if anon sign-in is off.
    private static func ensureSession() async {
        if (try? await SB.client.auth.session) == nil {
            _ = try? await SB.client.auth.signInAnonymously()
        }
    }

    // MARK: - Row mapping (the columns we read back)

    struct OrderRow: Decodable {
        let id: UUID
        let user_id: String?
        let service_id: String?
        let service_name_ar: String?
        let service_name_en: String?
        let minutes: Int?
        let duration_min: Int?
        let price: Int?
        let therapist_id: String?
        let therapist_name: String?
        let booking_date: String
        let booking_time: String
        let address_line: String?
        let building: String?
        let apartment: String?
        let district: String?
        let city: String?
        let lat: Double?
        let lng: Double?
        let customer_name: String?
        let contact_phone: String?
        let notes: String?
        let payment_method: String?
        let status: String?

        func toBooking() -> Booking {
            Booking(
                id: id,
                massageId: service_id ?? "",
                massageNameAr: service_name_ar ?? "",
                massageNameEn: service_name_en ?? "",
                minutes: duration_min ?? minutes ?? 60,
                durationMin: duration_min ?? minutes ?? 60,
                price: price ?? 0,
                dateISO: booking_date,
                time: booking_time,
                therapistId: therapist_id ?? "",
                therapistName: therapist_name ?? "",
                name: customer_name ?? "",
                contactPhone: contact_phone ?? "",
                addressLine: address_line ?? "",
                building: building ?? "",
                apartment: apartment ?? "",
                district: district ?? "",
                city: city ?? "Jeddah",
                lat: lat,
                lng: lng,
                notes: notes ?? "",
                paymentMethod: payment_method.flatMap(PaymentMethod.init(serverValue:)) ?? .onArrival,
                status: status.flatMap(BookingStatus.init(rawValue:)) ?? .pending
            )
        }
    }

    private static let selectCols =
        "id,user_id,service_id,service_name_ar,service_name_en,minutes,duration_min,price,therapist_id,therapist_name,booking_date,booking_time,address_line,building,apartment,district,city,lat,lng,customer_name,contact_phone,notes,payment_method,status,created_at"

    // MARK: - Customer

    /// Create the order server-side. Returns the server row (authoritative id +
    /// price + status) on success, or nil when offline/unconfigured (caller falls
    /// back to an on-device copy so the app still works without a backend).
    static func create(_ b: Booking) async -> Booking? {
        guard Config.isConfigured else { return nil }
        do {
            await ensureSession()
            let scheduled = "\(b.dateISO)T\(b.time):00+03:00"   // slot is Riyadh local time
            let params = CreateParams(
                p_service_id: b.massageId, p_duration_min: b.durationMin, p_therapist_id: b.therapistId,
                p_scheduled_at: scheduled, p_address_line: b.addressLine, p_building: b.building,
                p_apartment: b.apartment, p_district: b.district, p_city: b.city,
                p_lat: b.lat, p_lng: b.lng, p_notes: b.notes,
                p_payment_method: (b.paymentMethod ?? .onArrival).serverValue,
                p_customer_name: b.name, p_contact_phone: b.contactPhone)
            let row: OrderRow = try await SB.client.rpc("create_booking", params: params).execute().value
            return row.toBooking()
        } catch {
            return nil
        }
    }

    /// This customer's own orders from the cloud (RLS-scoped). [] when signed out.
    static func list() async -> [Booking] {
        guard Config.isConfigured else { return [] }
        do {
            await ensureSession()
            let rows: [OrderRow] = try await SB.client
                .from("bookings").select(selectCols)
                .order("booking_date", ascending: false)
                .execute().value
            return rows.map { $0.toBooking() }
        } catch { return [] }
    }

    /// Cancel via the RPC (enforces ownership + the 3-hour cutoff + state machine).
    @discardableResult
    static func cancel(_ id: UUID) async -> Bool {
        guard Config.isConfigured else { return false }
        do {
            await ensureSession()
            _ = try await SB.client.rpc("cancel_booking", params: CancelParams(p_id: id.uuidString)).execute()
            return true
        } catch { return false }
    }

    // MARK: - Owner / operator

    /// Is the signed-in user an operator (sees & drives all orders)?
    static func isAdmin() async -> Bool {
        guard Config.isConfigured else { return false }
        do {
            await ensureSession()
            return try await SB.client.rpc("is_admin", params: NoArgs()).execute().value
        } catch { return false }
    }

    /// Every order (admin RLS), newest first. Throws so the console can tell a
    /// failed load apart from a genuinely empty desk.
    static func allOrders() async throws -> [Booking] {
        guard Config.isConfigured else { return [] }
        await ensureSession()
        let rows: [OrderRow] = try await SB.client
            .from("bookings").select(selectCols)
            .order("created_at", ascending: false)
            .execute().value
        return rows.map { $0.toBooking() }
    }

    /// Drive an order through the lifecycle (admin only, server-validated).
    @discardableResult
    static func setStatus(_ id: UUID, _ status: BookingStatus) async -> Bool {
        guard Config.isConfigured else { return false }
        do {
            await ensureSession()
            _ = try await SB.client.rpc("admin_set_status",
                                        params: StatusParams(p_id: id.uuidString, p_status: status.rawValue)).execute()
            return true
        } catch { return false }
    }
}
