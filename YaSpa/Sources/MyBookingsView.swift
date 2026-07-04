import SwiftUI

struct MyBookingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @EnvironmentObject var data: DataStore
    @State private var cancelTarget: Booking?

    var body: some View {
        NavigationStack {
            Group {
                if store.bookings.isEmpty {
                    empty
                } else {
                    ScrollView {
                        VStack(spacing: Space.m) {
                            ForEach(store.bookings) { b in card(b) }
                        }
                        .padding(Space.screen)
                        .padding(.bottom, Space.xl)
                    }
                    .refreshable { store.merge(await CloudBookings.list()) }
                }
            }
            .background(AmbientBackground())
            .navigationTitle(app.t("حجوزاتي", "My bookings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline).foregroundStyle(Brand.pinkDeep)
                }
            }
            .navigationDestination(for: Massage.self) { MassageDetailView(massage: $0) }
            .navigationDestination(for: Therapist.self) { TherapistProfileView(therapist: $0) }
            .confirmationDialog(
                app.t("إلغاء هذا الحجز؟", "Cancel this booking?"),
                isPresented: Binding(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }),
                presenting: cancelTarget
            ) { b in
                Button(app.t("إلغاء الحجز", "Cancel booking"), role: .destructive) {
                    withAnimation { store.remove(b) }
                }
                Button(app.t("تراجع", "Keep it"), role: .cancel) {}
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            ArchMedallion(symbol: "calendar.badge.plus", width: 80, height: 100)
            Text(app.t("لا توجد حجوزات بعد", "No bookings yet"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t("اختاري مساجكِ من صفحة المساج", "Pick your massage from the Massage tab"))
                .font(.rubik(15)).foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Space.xxl)
    }

    private func card(_ b: Booking) -> some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.m) {
                GradientMonogramAvatar(seed: b.therapistName,
                                       initials: String(b.therapistName.prefix(1)),
                                       size: 46, verified: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.t(b.massageNameAr, b.massageNameEn))
                        .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                    Text("\(b.dateISO) · \(b.time)")
                        .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
                    Text("\(b.therapistName) · \(b.district)")
                        .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
                    if let pm = b.paymentMethod {
                        Label(pm.label(ar: app.isAr), systemImage: pm.symbol)
                            .font(.rubik(12, .medium)).foregroundStyle(Brand.pinkDeep)
                    }
                }
                Spacer(minLength: 0)
                Text(app.money(Pricing.total(b.price)))
                    .spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
            }
            HStack(spacing: Space.m) {
                if let m = data.massages.first(where: { $0.id == b.massageId }) {
                    NavigationLink(value: m) {
                        Label(app.t("احجزي مجددًا", "Rebook"), systemImage: "arrow.clockwise")
                            .font(.rubik(13, .semibold))
                            .foregroundStyle(Brand.pinkDeep)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Brand.bg2).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    Haptics.tap(); cancelTarget = b
                } label: {
                    Text(app.t("إلغاء", "Cancel"))
                        .font(.rubik(13, .semibold))
                        .foregroundStyle(Brand.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .overlay(Capsule().stroke(Brand.bg2, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cancel-booking")
            }
        }
        .padding(Space.l)
        .softCard()
        .accessibilityIdentifier("booking-row")
        .contextMenu {
            Button(role: .destructive) { store.remove(b) } label: {
                Label(app.t("حذف", "Delete"), systemImage: "trash")
            }
        }
    }
}
