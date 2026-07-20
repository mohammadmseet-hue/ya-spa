import Foundation
import Supabase

/// The outcome of a booking attempt. A "serious" booking flow tells the customer
/// exactly what happened — a slot conflict, a bad time, a network problem — instead
/// of one generic "something went wrong". The UI maps each case to its own message
/// (and, for `.slotTaken`, refreshes the grid so the taken time disappears).
enum BookingResult: Sendable {
    case success(Booking)
    case slotTaken          // someone booked that therapist/slot first (23505 / "slot_taken")
    case invalidTime        // the chosen time is in the past (22023 / "invalid_time")
    case notConnected       // offline / backend unreachable / couldn't establish a session
    case timedOut           // the request took too long — never leave the button spinning
    case failed(String)     // any other server-side rejection; message kept for diagnostics
}

/// A last-resort deadline around an async operation. The URLSession config in `SB`
/// already caps each request, but this guarantees a user-visible cap even against a
/// non-network stall (DNS resolution edge cases, actor contention): the Book button
/// can NEVER spin indefinitely. Cancels the in-flight work when the deadline wins.
struct OperationTimeout: Error {}

func withTimeout<T: Sendable>(
    _ seconds: Double,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw OperationTimeout()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

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
    private struct RescheduleParams: Encodable { let p_id: String; let p_scheduled_at: String }
    private struct NoArgs: Encodable {}

    /// Guarantee a session exists before any authed call, so a booking never
    /// races the launch-time anonymous sign-in (create_booking rejects a null
    /// auth.uid()). Reuses the persisted anonymous identity — `currentSession` is a
    /// synchronous, non-throwing read of stored credentials, so we only hit the
    /// network to MINT an identity when there genuinely isn't one (first launch).
    /// That keeps every device on ONE stable anon user (so her bookings persist and
    /// list under RLS) and avoids spamming anonymous sign-ins on every read. An
    /// existing-but-expired token is refreshed lazily by the RPC layer.
    /// Best-effort: swallows failure. Use `establishSession()` when the caller needs
    /// to distinguish an auth/network failure from success.
    private static func ensureSession() async {
        if SB.client.auth.currentSession == nil {
            _ = try? await SB.client.auth.signInAnonymously()
        }
    }

    /// Throwing variant for the write path: mints the anonymous identity when absent
    /// and lets a network/timeout failure propagate so `create` can report it precisely
    /// (`.notConnected` / `.timedOut`) instead of silently proceeding into an RPC that
    /// would only fail with a null `auth.uid()`.
    private static func establishSession() async throws {
        if SB.client.auth.currentSession == nil {
            _ = try await SB.client.auth.signInAnonymously()
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

    /// Create the order server-side and report a precise outcome. The server is
    /// authoritative for id/price/status. The whole operation is bounded by a hard
    /// deadline (belt-and-suspenders over the URLSession timeouts) so the caller's
    /// spinner is always released. `.notConnected` when unconfigured/offline so the
    /// caller can fall back to an on-device copy.
    static func create(_ b: Booking) async -> BookingResult {
        guard Config.isConfigured else { return .notConnected }
        do {
            return try await withTimeout(25) {
                try await establishSession()
                let scheduled = "\(b.dateISO)T\(b.time):00+03:00"   // slot is Riyadh local time
                let params = CreateParams(
                    p_service_id: b.massageId, p_duration_min: b.durationMin, p_therapist_id: b.therapistId,
                    p_scheduled_at: scheduled, p_address_line: b.addressLine, p_building: b.building,
                    p_apartment: b.apartment, p_district: b.district, p_city: b.city,
                    p_lat: b.lat, p_lng: b.lng, p_notes: b.notes,
                    p_payment_method: (b.paymentMethod ?? .onArrival).serverValue,
                    p_customer_name: b.name, p_contact_phone: b.contactPhone)
                let row: OrderRow = try await SB.client.rpc("create_booking", params: params).execute().value
                return .success(row.toBooking())
            }
        } catch {
            return classify(error)
        }
    }

    /// Map a thrown error to a customer-facing outcome. Codes/messages verified against
    /// the live backend: slot conflict → 23505/"slot_taken", past time → 22023/"invalid_time",
    /// missing auth → 28000/"not_authenticated".
    private static func classify(_ error: Error) -> BookingResult {
        if error is OperationTimeout { return .timedOut }
        if error is CancellationError { return .timedOut }

        if let pg = error as? PostgrestError {
            if pg.code == "23505" || pg.message == "slot_taken" { return .slotTaken }
            if pg.message == "invalid_time"                     { return .invalidTime }
            if pg.message == "not_authenticated"                { return .notConnected } // session couldn't be minted
            return .failed(pg.message)
        }

        if let urlErr = error as? URLError {
            return urlErr.code == .timedOut ? .timedOut
                                            : .notConnected  // offline / can't reach host / connection lost
        }

        // AuthError.sessionMissing (anon sign-in failed) and anything else network-shaped.
        return .notConnected
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

    /// Move an existing pending/confirmed order to a new slot via the RPC (enforces ownership,
    /// future-time, and the anti-double-booking index). Returns the updated row on success, or
    /// nil on conflict/offline — the caller keeps the old slot and surfaces the failure.
    static func reschedule(_ id: UUID, dateISO: String, time: String) async -> Booking? {
        guard Config.isConfigured else { return nil }
        do {
            await ensureSession()
            let scheduled = "\(dateISO)T\(time):00+03:00"   // Riyadh local, same format as create()
            let row: OrderRow = try await SB.client
                .rpc("reschedule_booking",
                     params: RescheduleParams(p_id: id.uuidString, p_scheduled_at: scheduled))
                .execute().value
            return row.toBooking()
        } catch { return nil }
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
