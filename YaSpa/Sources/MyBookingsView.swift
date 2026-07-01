import SwiftUI

struct MyBookingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore

    var body: some View {
        NavigationStack {
            Group {
                if store.bookings.isEmpty {
                    empty
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.bookings) { b in
                                card(b)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Brand.bg.ignoresSafeArea())
            .navigationTitle(app.t("حجوزاتي", "My bookings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(app.isAr ? "EN" : "ع") { app.toggle() }
                        .font(.headline)
                        .foregroundStyle(Brand.pinkDeep)
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 46))
                .foregroundStyle(Brand.pinkSoft)
            Text(app.t("لا توجد حجوزات بعد", "No bookings yet"))
                .font(.headline).foregroundStyle(Brand.ink)
            Text(app.t("اختاري مساجكِ من صفحة المساج", "Pick your massage from the Massage tab"))
                .font(.subheadline).foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func card(_ b: Booking) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.t(b.massageNameAr, b.massageNameEn))
                    .font(.headline).foregroundStyle(Brand.ink)
                Text("\(b.dateISO) · \(b.time)")
                    .font(.caption).foregroundStyle(Brand.muted)
                Text(b.district)
                    .font(.caption2).foregroundStyle(Brand.muted)
            }
            Spacer(minLength: 0)
            Text(app.money(Pricing.total(b.price)))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.pinkDeep)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                store.remove(b)
            } label: {
                Label(app.t("حذف", "Delete"), systemImage: "trash")
            }
        }
    }
}
