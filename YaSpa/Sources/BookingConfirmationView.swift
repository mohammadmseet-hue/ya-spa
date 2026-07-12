import SwiftUI

struct BookingConfirmationView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let booking: Booking

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                YaSpaWordmark(compact: true).padding(.top, Space.xxl)
                AnimatedCheckmark().padding(.top, Space.s)

                Text(app.t("تم تأكيد حجزكِ 🌸", "You're booked 🌸"))
                    .spaFont(.serviceName, ar: app.isAr)
                    .foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("confirmation-title")

                summaryCard

                Text(app.t("سنتواصل معكِ لتأكيد معالِجتكِ قريبًا.",
                           "We'll reach out shortly to confirm your therapist."))
                    .font(.rubik(14))
                    .foregroundStyle(Brand.inkSoft)
                    .multilineTextAlignment(.center)

                Button {
                    openURL(whatsappURL())
                } label: {
                    Label(app.t("أرسلي التفاصيل عبر واتساب", "Send details on WhatsApp"),
                          systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(app.t("تم", "Done")) { dismiss() }
                    .font(.rubik(16, .semibold))
                    .foregroundStyle(Brand.inkSoft)
                    .padding(.top, 2)
                    .accessibilityIdentifier("confirmation-done")
            }
            .padding(Space.screen)
            .padding(.bottom, Space.huge)
        }
        .background(AmbientBackground())
    }

    private var summaryCard: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.m) {
                GradientMonogramAvatar(seed: booking.therapistName,
                                       initials: String(booking.therapistName.prefix(1)),
                                       size: 44, verified: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t(booking.massageNameAr, booking.massageNameEn))
                        .spaFont(.cardTitle, ar: app.isAr).foregroundStyle(Brand.ink)
                    Text(booking.therapistName)
                        .font(.rubik(13)).foregroundStyle(Brand.inkSoft)
                }
                Spacer(minLength: 0)
            }
            Divider()
            detail(app.t("المدة", "Duration"), app.t("\(booking.durationMin) دقيقة", "\(booking.durationMin) min"))
            detail(app.t("التاريخ", "Date"),
                   Scheduling.longDate(Scheduling.parse(booking.dateISO) ?? Date(), ar: app.isAr))
            detail(app.t("الوقت", "Time"), booking.time)
            detail(app.t("الحي", "District"), booking.district)
            detail(app.t("الدفع", "Payment"),
                   (booking.paymentMethod ?? .onArrival).label(ar: app.isAr))
            Divider()
            HStack {
                Text(app.t("الإجمالي", "Total"))
                    .font(.rubik(17, .semibold)).foregroundStyle(Brand.ink)
                Spacer()
                Text(app.money(Pricing.total(booking.price)))
                    .spaFont(.price, ar: app.isAr).foregroundStyle(Brand.pinkDeep)
            }
        }
        .padding(Space.l)
        .softCard()
    }

    private func detail(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.rubik(15)).foregroundStyle(Brand.inkSoft)
            Spacer()
            Text(value).font(.rubik(15, .semibold)).foregroundStyle(Brand.ink)
        }
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
