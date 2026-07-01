import SwiftUI

struct BookingConfirmationView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var pop = false
    let booking: Booking

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            ZStack {
                Circle().fill(Brand.bg2).frame(width: 108, height: 108)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Brand.pinkDeep)
            }
            .scaleEffect(pop ? 1 : 0.6)
            .opacity(pop ? 1 : 0)
            .onAppear {
                Haptics.success()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { pop = true }
            }

            Text(app.t("تم تأكيد حجزكِ 🌸", "Your booking is confirmed 🌸"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("confirmation-title")

            VStack(spacing: 10) {
                detail(app.t("الخدمة", "Service"), app.t(booking.massageNameAr, booking.massageNameEn))
                detail(app.t("التاريخ", "Date"), booking.dateISO)
                detail(app.t("الوقت", "Time"), booking.time)
                detail(app.t("المعالِجة", "Therapist"), booking.therapistName)
                detail(app.t("الحي", "District"), booking.district)
                detail(app.t("الدفع", "Payment"),
                       (booking.paymentMethod ?? .onArrival).label(ar: app.isAr))
                detail(app.t("الإجمالي", "Total"), app.money(Pricing.total(booking.price)))
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(app.t("سنؤكّد معالِجتكِ عبر واتساب خلال دقائق.",
                       "We'll confirm your therapist on WhatsApp within minutes."))
                .font(.footnote)
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button {
                openURL(whatsappURL())
            } label: {
                Label(app.t("أرسلي التفاصيل عبر واتساب", "Send details on WhatsApp"),
                      systemImage: "paperplane.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(app.t("تم", "Done")) { dismiss() }
                .font(.headline)
                .foregroundStyle(Brand.muted)
                .padding(.top, 2)
                .accessibilityIdentifier("confirmation-done")
        }
        .padding(20)
        .background(Brand.bg.ignoresSafeArea())
    }

    private func detail(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(Brand.muted)
            Spacer()
            Text(value).foregroundStyle(Brand.ink).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func whatsappURL() -> URL {
        let notesLine = booking.notes.isEmpty ? "" :
            (app.isAr ? "\nملاحظات: \(booking.notes)" : "\nNotes: \(booking.notes)")
        let pay = (booking.paymentMethod ?? .onArrival).label(ar: app.isAr)
        let msg = app.isAr
            ? "مرحبًا يا سبا 🌸\nحجز مساج:\n• \(booking.massageNameAr) (\(booking.minutes) د)\n• التاريخ: \(booking.dateISO)\n• الوقت: \(booking.time)\n• المعالِجة: \(booking.therapistName)\n• الاسم: \(booking.name)\n• الحي: \(booking.district)\n• الدفع: \(pay)\n• الإجمالي: \(app.money(Pricing.total(booking.price)))\(notesLine)"
            : "Hello Ya Spa 🌸\nMassage booking:\n• \(booking.massageNameEn) (\(booking.minutes) min)\n• Date: \(booking.dateISO)\n• Time: \(booking.time)\n• Therapist: \(booking.therapistName)\n• Name: \(booking.name)\n• District: \(booking.district)\n• Payment: \(pay)\n• Total: \(app.money(Pricing.total(booking.price)))\(notesLine)"
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/966565722923?text=\(encoded)")
            ?? URL(string: "https://wa.me/966565722923")!
    }
}
