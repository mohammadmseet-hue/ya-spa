import SwiftUI

/// The operator's order desk. Shows every order (admin RLS), auto-refreshes,
/// and drives each one through the lifecycle via the server-validated
/// admin_set_status RPC — with tap-to-call and tap-to-navigate to the customer.
struct OwnerConsoleView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.openURL) private var openURL
    @State private var orders: [Booking] = []
    @State private var loading = false
    @State private var loadFailed = false
    @State private var filter: Filter = .active

    enum Filter: String, CaseIterable, Identifiable {
        case active, today, all
        var id: String { rawValue }
        func label(_ ar: Bool) -> String {
            switch self {
            case .active: return ar ? "الجارية" : "Active"
            case .today:  return ar ? "اليوم" : "Today"
            case .all:    return ar ? "الكل" : "All"
            }
        }
    }

    private var shown: [Booking] {
        switch filter {
        case .active: return orders.filter { ($0.status ?? .pending).isActive }
        case .today:  return orders.filter { $0.dateISO == Scheduling.iso(Date()) }
        case .all:    return orders
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed && orders.isEmpty {
                    errorState
                } else if shown.isEmpty {
                    empty
                } else {
                    ScrollView {
                        VStack(spacing: Space.m) {
                            ForEach(shown) { card($0) }
                        }
                        .padding(Space.screen).padding(.bottom, Space.xl)
                    }
                    .refreshable { await load() }
                }
            }
            .background(AmbientBackground())
            .navigationTitle(app.t("الطلبات", "Orders"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) { filterBar }
        }
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)   // live-ish poll, every 20s
                if Task.isCancelled { break }
                await load()
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: Space.s) {
            ForEach(Filter.allCases) { f in
                let on = filter == f
                Button {
                    Haptics.tap(); filter = f
                } label: {
                    Text(f.label(app.isAr))
                        .font(.rubik(13, .semibold))
                        .foregroundStyle(on ? Brand.paper : Brand.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(on ? AnyShapeStyle(Brand.brandGradient) : AnyShapeStyle(Brand.paper))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Brand.bg2, lineWidth: on ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if loading { ProgressView().tint(Brand.pinkDeep) }
        }
        .padding(.horizontal, Space.screen).padding(.vertical, Space.s)
        .background(.ultraThinMaterial)
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            ArchMedallion(symbol: "tray", width: 80, height: 100)
            Text(app.t("لا توجد طلبات", "No orders"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t("ستظهر الطلبات الجديدة هنا فورًا.", "New orders appear here instantly."))
                .font(.rubik(15)).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(Space.xxl)
    }

    private var errorState: some View {
        VStack(spacing: Space.l) {
            ArchMedallion(symbol: "wifi.exclamationmark", width: 80, height: 100)
            Text(app.t("تعذّر تحميل الطلبات", "Couldn't load orders"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            Button(app.t("إعادة المحاولة", "Retry")) { Task { await load() } }
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(Space.xxl)
    }

    private func card(_ b: Booking) -> some View {
        let status = b.status ?? .pending
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.t(b.massageNameAr, b.massageNameEn))
                        .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                    Text("\(b.durationMin) \(app.t("د", "min")) · \(b.dateISO) · \(b.time)")
                        .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
                }
                Spacer(minLength: 0)
                statusChip(status)
            }
            Divider()
            infoRow("person.fill", b.name.isEmpty ? "—" : b.name)
            if !b.contactPhone.isEmpty { infoRow("phone.fill", b.contactPhone) }
            infoRow("mappin.circle.fill", addressText(b))
            infoRow("banknote", "\(app.money(Pricing.total(b.price))) · \(b.therapistName)")

            HStack(spacing: Space.s) {
                if !b.contactPhone.isEmpty {
                    action("phone.fill", app.t("اتصال", "Call")) { call(b) }
                }
                action("map.fill", app.t("الوصول", "Navigate")) { navigate(b) }
            }
            lifecycleButtons(b, status)
        }
        .padding(Space.l)
        .softCard()
    }

    private func addressText(_ b: Booking) -> String {
        [b.addressLine, b.building.isEmpty ? nil : "Bldg \(b.building)",
         b.apartment.isEmpty ? nil : "Apt \(b.apartment)", b.district, b.city]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Brand.pinkDeep).frame(width: 18)
            Text(text).font(.rubik(13)).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func statusChip(_ s: BookingStatus) -> some View {
        Text(s.label(ar: app.isAr))
            .font(.rubik(11, .semibold))
            .foregroundStyle(Brand.paper)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(chipColor(s)).clipShape(Capsule())
    }

    private func chipColor(_ s: BookingStatus) -> Color {
        switch s {
        case .pending:   return Brand.gold
        case .confirmed: return Brand.accent
        case .onTheWay:  return Brand.pinkDeep
        case .completed: return Color(hex: 0x3E7C5A)
        case .cancelled, .noShow: return Brand.inkSoft
        }
    }

    private func action(_ icon: String, _ title: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon)
                .font(.rubik(13, .semibold)).foregroundStyle(Brand.pinkDeep)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Brand.bg2).clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func lifecycleButtons(_ b: Booking, _ status: BookingStatus) -> some View {
        switch status {
        case .pending:
            HStack(spacing: Space.s) {
                primary(app.t("تأكيد", "Confirm")) { setStatus(b, .confirmed) }
                secondary(app.t("رفض", "Decline")) { setStatus(b, .cancelled) }
            }
        case .confirmed:
            HStack(spacing: Space.s) {
                primary(app.t("في الطريق", "On the way")) { setStatus(b, .onTheWay) }
                secondary(app.t("إلغاء", "Cancel")) { setStatus(b, .cancelled) }
            }
        case .onTheWay:
            primary(app.t("اكتمل", "Completed")) { setStatus(b, .completed) }
        default:
            EmptyView()
        }
    }

    private func primary(_ title: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { Text(title) }
            .buttonStyle(PrimaryButtonStyle())
    }

    private func secondary(_ title: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(.rubik(15, .semibold)).foregroundStyle(Brand.inkSoft)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).stroke(Brand.bg2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: actions

    private func load() async {
        loading = true
        do {
            orders = try await CloudBookings.allOrders()
            loadFailed = false
        } catch {
            loadFailed = true   // keep last-known orders rather than wiping to []
        }
        loading = false
    }

    private func setStatus(_ b: Booking, _ s: BookingStatus) {
        Haptics.tap()
        Task {
            if await CloudBookings.setStatus(b.id, s) { await load() }
        }
    }

    private func call(_ b: Booking) {
        let digits = b.contactPhone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(digits)") { openURL(url) }
    }

    private func navigate(_ b: Booking) {
        if let url = b.mapsURL { openURL(url) }
    }
}
