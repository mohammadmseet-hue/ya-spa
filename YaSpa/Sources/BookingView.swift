import SwiftUI

struct BookingView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: BookingStore
    @Environment(\.dismiss) private var dismiss
    let massage: Massage

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedTime: String?
    @State private var selectedTherapist: Therapist?
    @State private var name = ""
    @State private var district = ""
    @State private var notes = ""
    @State private var payment: PaymentMethod = .onArrival
    @State private var confirmed: Booking?

    private let days = Scheduling.upcomingDays(14)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var canBook: Bool {
        selectedTime != nil
            && selectedTherapist != nil
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !district.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var currentStep: Int {
        var s = 0
        if selectedTime != nil { s = 1 }
        if selectedTherapist != nil { s = 2 }
        if canBook { s = 3 }
        return s
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                StepProgress(total: 4, current: currentStep).padding(.top, Space.s)
                header
                daySelector
                timeGrid
                therapistSection
                detailsForm
                paymentSection
                priceSummary
            }
            .padding(Space.screen)
            .padding(.bottom, 96)   // clearance so nothing sits under the sticky book bar
        }
        .background(AmbientBackground())
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(app.t("احجزي موعدكِ", "Book your slot"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bookBar }
        .fullScreenCover(item: $confirmed, onDismiss: { dismiss() }) { b in
            BookingConfirmationView(booking: b)
        }
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            SFSymbolMedallion(symbol: massage.symbol, size: 50, rounded: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.t(massage.nameAr, massage.nameEn))
                    .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                Text(app.t("\(massage.minutes) دقيقة · \(app.money(massage.price))",
                           "\(massage.minutes) min · \(app.money(massage.price))"))
                    .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.l)
        .softCard()
    }

    private func sectionTitle(_ ar: String, _ en: String, _ icon: String) -> some View {
        Label(app.t(ar, en), systemImage: icon)
            .spaFont(.section, ar: app.isAr)
            .foregroundStyle(Brand.ink)
    }

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            sectionTitle("اختاري اليوم", "Choose a day", "calendar")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { day in
                        let selected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                    .stroke(Brand.bg2, lineWidth: selected ? 0 : 1)
                            )
                            .shadow(color: Brand.shadowBloom.opacity(selected ? 0.25 : 0), radius: 10, y: 5)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("day-\(Scheduling.iso(day))")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var timeGrid: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                sectionTitle("اختاري الوقت", "Choose a time", "clock")
                Spacer()
                Text(Scheduling.longDate(selectedDay, ar: app.isAr))
                    .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Scheduling.slots(), id: \.self) { time in
                    let available = Scheduling.isAvailable(day: selectedDay, time: time)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                                    .stroke(Brand.bg2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                    .accessibilityIdentifier("slot-\(time)")
                }
            }
        }
    }

    private var therapistSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            sectionTitle("اختاري معالِجتكِ", "Choose your therapist", "person.crop.circle")
            ForEach(Therapists.all) { th in
                let selected = selectedTherapist?.id == th.id
                Button {
                    Haptics.tap()
                    withAnimation(Motion.spring) { selectedTherapist = th }
                } label: {
                    HStack(spacing: Space.m) {
                        GradientMonogramAvatar(seed: th.id,
                                               initials: String(app.t(th.nameAr, th.nameEn).prefix(1)),
                                               size: 46, verified: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.t(th.nameAr, th.nameEn))
                                .font(.rubik(15, .semibold)).foregroundStyle(Brand.ink)
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Brand.gold)
                                Text("\(String(format: "%.2f", th.rating)) · \(th.reviews)")
                                    .font(.rubik(12)).foregroundStyle(Brand.inkSoft)
                                Text("· \(app.t(th.specialtyAr, th.specialtyEn))")
                                    .font(.rubik(12)).foregroundStyle(Brand.inkSoft).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Brand.pinkDeep : Brand.inkSoft.opacity(0.4))
                    }
                    .padding(Space.m)
                    .softCard(selected: selected)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("therapist-\(th.id)")
            }
        }
    }

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            sectionTitle("بياناتكِ", "Your details", "person")
            field(app.t("الاسم", "Name"), id: "field-name", text: $name)
            field(app.t("الحي في جدة", "District in Jeddah"), id: "field-district", text: $district)
            field(app.t("ملاحظات (اختياري)", "Notes (optional)"), id: "field-notes", text: $notes)
        }
    }

    private func field(_ placeholder: String, id: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.rubik(16))
            .accessibilityIdentifier(id)
            .padding(Space.l)
            .background(Brand.paper)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(text.wrappedValue.isEmpty ? Brand.bg2 : Brand.pink.opacity(0.5), lineWidth: 1)
            )
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            sectionTitle("طريقة الدفع", "Payment method", "creditcard")
            paymentOption(.onArrival, enabled: true)
            paymentOption(.applePay, enabled: Config.paymentsEnabled)
            paymentOption(.card, enabled: Config.paymentsEnabled)
        }
    }

    private func paymentOption(_ method: PaymentMethod, enabled: Bool) -> some View {
        let selected = payment == method
        return Button {
            guard enabled else { return }
            Haptics.tap()
            withAnimation(Motion.press) { payment = method }
        } label: {
            HStack(spacing: Space.m) {
                Image(systemName: method.symbol)
                    .font(.title3).foregroundStyle(enabled ? Brand.pinkDeep : Brand.inkSoft.opacity(0.5))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.label(ar: app.isAr))
                        .font(.rubik(15, .semibold))
                        .foregroundStyle(enabled ? Brand.ink : Brand.inkSoft)
                    Text(method.note(ar: app.isAr)).font(.rubik(12)).foregroundStyle(Brand.inkSoft)
                }
                Spacer(minLength: 0)
                if enabled {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Brand.pinkDeep : Brand.inkSoft.opacity(0.4))
                } else {
                    Text(app.t("قريبًا", "Soon"))
                        .font(.rubik(11, .semibold)).foregroundStyle(Brand.pinkDeep)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Brand.bg2).clipShape(Capsule())
                }
            }
            .padding(Space.m)
            .softCard(selected: selected && enabled)
            .opacity(enabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("pay-\(method.rawValue)")
    }

    private var priceSummary: some View {
        VStack(spacing: Space.s) {
            row(app.t("الجلسة", "Session"), massage.price)
            row(app.t("المواصلات", "Transport"), Pricing.transport)
            row(app.t("ضريبة ١٥٪", "VAT 15%"), Pricing.vat(massage.price))
            Divider()
            row(app.t("الإجمالي", "Total"), Pricing.total(massage.price), bold: true)
        }
        .padding(Space.l)
        .softCard()
    }

    private func row(_ label: String, _ amount: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.rubik(bold ? 17 : 15, bold ? .semibold : .regular))
                .foregroundStyle(bold ? Brand.ink : Brand.inkSoft)
            Spacer()
            if bold {
                Text(app.money(amount)).spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
            } else {
                Text(app.money(amount)).font(.rubik(15)).foregroundStyle(Brand.ink)
            }
        }
    }

    private var bookBar: some View {
        StickyGlassBar {
            HStack(spacing: Space.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t("الإجمالي", "Total"))
                        .font(.rubik(11)).foregroundStyle(Brand.inkSoft)
                    Text(app.money(Pricing.total(massage.price)))
                        .spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
                }
                Button {
                    book()
                } label: {
                    Text(canBook ? app.t("تأكيد الحجز", "Confirm booking")
                                 : app.t("أكملي بياناتكِ", "Complete your details"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("confirm-booking")
                .disabled(!canBook)
                .opacity(canBook ? 1 : 0.55)
            }
        }
    }

    private func book() {
        guard let time = selectedTime, let therapist = selectedTherapist else { return }
        let b = Booking(massageId: massage.id,
                        massageNameAr: massage.nameAr,
                        massageNameEn: massage.nameEn,
                        minutes: massage.minutes,
                        price: massage.price,
                        dateISO: Scheduling.iso(selectedDay),
                        time: time,
                        therapistName: app.t(therapist.nameAr, therapist.nameEn),
                        name: name.trimmingCharacters(in: .whitespaces),
                        district: district.trimmingCharacters(in: .whitespaces),
                        notes: notes.trimmingCharacters(in: .whitespaces),
                        paymentMethod: payment)
        store.add(b)
        Haptics.success()
        Task { await CloudBookings.save(b) }
        confirmed = b
    }
}
