import SwiftUI

struct BookingView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @Environment(\.dismiss) private var dismiss
    let massage: Massage

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedTime: String?
    @State private var name = ""
    @State private var district = ""
    @State private var notes = ""
    @State private var confirmed: Booking?

    private let days = Scheduling.upcomingDays(14)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var canBook: Bool {
        selectedTime != nil
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !district.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                daySelector
                timeGrid
                detailsForm
                priceSummary
            }
            .padding(16)
        }
        .background(Brand.bg.ignoresSafeArea())
        .navigationTitle(app.t("احجزي موعدكِ", "Book your slot"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bookBar }
        .fullScreenCover(item: $confirmed, onDismiss: { dismiss() }) { b in
            BookingConfirmationView(booking: b)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: massage.symbol)
                .font(.title2).foregroundStyle(Brand.pinkDeep)
                .frame(width: 46, height: 46)
                .background(Brand.bg2).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(app.t(massage.nameAr, massage.nameEn))
                    .font(.headline).foregroundStyle(Brand.ink)
                Text(app.t("\(massage.minutes) دقيقة · \(app.money(massage.price))",
                           "\(massage.minutes) min · \(app.money(massage.price))"))
                    .font(.caption).foregroundStyle(Brand.muted)
            }
            Spacer(minLength: 0)
        }
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(app.t("اختاري اليوم", "Choose a day"), systemImage: "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { day in
                        let selected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            selectedDay = day
                            selectedTime = nil
                        } label: {
                            VStack(spacing: 4) {
                                Text(Scheduling.weekday(day, ar: app.isAr)).font(.caption2)
                                Text(Scheduling.dayNumber(day)).font(.headline)
                            }
                            .frame(width: 54, height: 66)
                            .background(selected ? Brand.brandGradient : Brand.whiteGradient)
                            .foregroundStyle(selected ? Color.white : Brand.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Brand.bg2, lineWidth: selected ? 0 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var timeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(app.t("اختاري الوقت", "Choose a time"), systemImage: "clock")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Scheduling.slots(), id: \.self) { time in
                    let available = Scheduling.isAvailable(day: selectedDay, time: time)
                    let selected = selectedTime == time
                    Button {
                        if available { selectedTime = time }
                    } label: {
                        Text(time)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selected ? Brand.pinkDeep : Color.white)
                            .foregroundStyle(selected ? Color.white
                                             : (available ? Brand.ink : Brand.muted.opacity(0.35)))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Brand.bg2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                }
            }
        }
    }

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(app.t("بياناتكِ", "Your details"), systemImage: "person")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            field(app.t("الاسم", "Name"), text: $name)
            field(app.t("الحي في جدة", "District in Jeddah"), text: $district)
            field(app.t("ملاحظات (اختياري)", "Notes (optional)"), text: $notes)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Brand.bg2, lineWidth: 1)
            )
    }

    private var priceSummary: some View {
        VStack(spacing: 8) {
            row(app.t("الجلسة", "Session"), massage.price)
            row(app.t("المواصلات", "Transport"), Pricing.transport)
            row(app.t("ضريبة ١٥٪", "VAT 15%"), Pricing.vat(massage.price))
            Divider()
            row(app.t("الإجمالي", "Total"), Pricing.total(massage.price), bold: true)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ label: String, _ amount: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(bold ? Brand.ink : Brand.muted)
            Spacer()
            Text(app.money(amount))
                .foregroundStyle(bold ? Brand.pinkDeep : Brand.ink)
                .fontWeight(bold ? .bold : .regular)
        }
        .font(bold ? .headline : .subheadline)
    }

    private var bookBar: some View {
        Button {
            book()
        } label: {
            Text(canBook
                 ? app.t("تأكيد الحجز · \(app.money(Pricing.total(massage.price)))",
                         "Confirm · \(app.money(Pricing.total(massage.price)))")
                 : app.t("اختاري الوقت وأكملي بياناتكِ", "Pick a time & fill your details"))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canBook)
        .opacity(canBook ? 1 : 0.6)
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func book() {
        guard let time = selectedTime else { return }
        let b = Booking(massageId: massage.id,
                        massageNameAr: massage.nameAr,
                        massageNameEn: massage.nameEn,
                        minutes: massage.minutes,
                        price: massage.price,
                        dateISO: Scheduling.iso(selectedDay),
                        time: time,
                        name: name.trimmingCharacters(in: .whitespaces),
                        district: district.trimmingCharacters(in: .whitespaces),
                        notes: notes.trimmingCharacters(in: .whitespaces))
        store.add(b)
        confirmed = b
    }
}
