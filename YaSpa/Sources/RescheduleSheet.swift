import SwiftUI

/// A focused day + time picker to move an existing booking to a new slot. Reuses the same
/// scheduling primitives and taken-slot check as BookingView, and calls the server-authoritative
/// reschedule_booking RPC (ownership + future-time + anti-double-booking enforced server-side).
struct RescheduleSheet: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var data: DataStore
    @Environment(\.dismiss) private var dismiss
    let booking: Booking
    let onDone: (Booking) -> Void

    @State private var selectedDay: Date = Scheduling.startOfToday()
    @State private var selectedTime: String?
    @State private var taken: Set<String> = []
    @State private var saving = false
    @State private var failed = false

    private let days = Scheduling.upcomingDays(14)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    daySelector
                    timeGrid
                }
                .padding(Space.screen)
                .padding(.bottom, 96)
            }
            .background(AmbientBackground())
            .navigationTitle(app.t("تغيير الموعد", "Reschedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(app.t("إلغاء", "Cancel")) { dismiss() }
                        .foregroundStyle(Brand.inkSoft)
                }
            }
            .safeAreaInset(edge: .bottom) { confirmBar }
            .task(id: Scheduling.iso(selectedDay)) {
                taken = await data.takenSlots(therapist: booking.therapistId, date: Scheduling.iso(selectedDay))
                if let t = selectedTime, taken.contains(t) { selectedTime = nil }
            }
            .alert(app.t("تعذّر تغيير الموعد", "Couldn't reschedule"), isPresented: $failed) {
                Button(app.t("حسناً", "OK"), role: .cancel) {}
            } message: {
                Text(app.t("قد يكون هذا الوقت محجوزًا، جرّبي وقتًا آخر.",
                           "That time may already be taken — please try another slot."))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.t(booking.massageNameAr, booking.massageNameEn))
                .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
            Text(app.t("الموعد الحالي: ", "Currently: ")
                 + Scheduling.display(iso: booking.dateISO, time: booking.time, ar: app.isAr))
                .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .softCard()
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(app.t("اختاري اليوم", "Choose a day"))
                .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { day in
                        let selected = Scheduling.cal.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            Haptics.tap()
                            withAnimation(Motion.spring) { selectedDay = day; selectedTime = nil }
                        } label: {
                            VStack(spacing: 4) {
                                Text(Scheduling.weekday(day, ar: app.isAr)).font(.rubik(12))
                                Text(Scheduling.dayNumber(day)).font(.rubik(18, .semibold))
                            }
                            .frame(width: 54, height: 68)
                            .background(selected ? AnyShapeStyle(Brand.brandGradient) : AnyShapeStyle(Brand.paper))
                            .foregroundStyle(selected ? Brand.paper : Brand.ink)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                .stroke(Brand.bg2, lineWidth: selected ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var timeGrid: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Text(app.t("اختاري الوقت", "Choose a time"))
                    .spaFont(.section, ar: app.isAr).foregroundStyle(Brand.ink)
                Spacer()
                Text(Scheduling.longDate(selectedDay, ar: app.isAr))
                    .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Scheduling.slots(), id: \.self) { time in
                    let available = Scheduling.isAvailable(day: selectedDay, time: time) && !taken.contains(time)
                    let selected = selectedTime == time
                    Button {
                        guard available else { return }
                        Haptics.tap()
                        withAnimation(Motion.press) { selectedTime = time }
                    } label: {
                        Text(time)
                            .font(.rubik(15, .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(selected ? AnyShapeStyle(Brand.brandGradient) : AnyShapeStyle(Brand.paper))
                            .foregroundStyle(selected ? Brand.paper
                                             : (available ? Brand.ink : Brand.inkSoft.opacity(0.35)))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                .stroke(Brand.bg2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                }
            }
        }
    }

    private var confirmBar: some View {
        StickyGlassBar {
            Button { confirm() } label: {
                if saving {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedTime == nil ? app.t("اختاري وقتًا", "Pick a time")
                                             : app.t("تأكيد الموعد الجديد", "Confirm new time"))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedTime == nil || saving)
            .opacity(selectedTime == nil || saving ? 0.55 : 1)
            .accessibilityIdentifier("confirm-reschedule")
        }
    }

    private func confirm() {
        guard let t = selectedTime else { return }
        let iso = Scheduling.iso(selectedDay)
        Haptics.success()
        if Runtime.isUITest || !Config.isConfigured {
            var b = booking; b.dateISO = iso; b.time = t
            onDone(b); dismiss(); return
        }
        saving = true
        Task {
            let updated = await CloudBookings.reschedule(booking.id, dateISO: iso, time: t)
            await MainActor.run {
                saving = false
                if let updated { onDone(updated); dismiss() }
                else { failed = true }
            }
        }
    }
}
