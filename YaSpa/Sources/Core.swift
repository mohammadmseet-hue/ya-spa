import SwiftUI
import Foundation
import UIKit

// MARK: - Haptics

enum Haptics {
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Runtime (UI-test determinism)

enum Runtime {
    static let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
}

// MARK: - Theme

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }
    /// A dynamic color that adapts to light and dusk (dark) appearance.
    init(light: UInt, dark: UInt) {
        self = Color(UIColor { tc in
            let hex = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                           green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }
}

enum Brand {
    // "Quiet luxury at-home hammam" — oat/bordeaux/gold by day, an espresso-black
    // dusk palette by night. Every value adapts to the appearance, so dark mode
    // cascades app-wide with zero view edits.
    static let pinkDeep = Color(light: 0x6E1E2E, dark: 0x9A3B4E)   // Bordeaux accent (lifted in dusk for AA)
    static let accent   = Color(light: 0x6E1E2E, dark: 0x9A3B4E)
    static let accentPressed = Color(light: 0x571623, dark: 0x7C2C3C)
    static let pink     = Color(light: 0xD9B3AC, dark: 0x855A5E)   // Clay Rose — tint only
    static let pinkSoft = Color(light: 0xE8CFC9, dark: 0x4A3A38)   // Dusty Rose — tint only
    static let gold     = Color(light: 0xA98545, dark: 0xC9A15E)   // Antique Gold (lifted in dusk)
    static let bg       = Color(light: 0xF4EFE7, dark: 0x161210)   // canvas
    static let bg2      = Color(light: 0xECE4D8, dark: 0x221C18)   // wash
    static let ink      = Color(light: 0x2A2320, dark: 0xF3EEE6)   // primary text (inverts in dusk)
    static let muted    = Color(light: 0x6B5F58, dark: 0xA99E94)   // secondary text
    static let paper    = Color(light: 0xFFFDFB, dark: 0x2C2420)   // cards
    static let hairline = Color(light: 0xDED5C8, dark: 0x3A322D)   // card edge
    static let ivory    = Color(light: 0xFBF7F0, dark: 0xFBF7F0)   // on-accent text (both modes)

    static let heroGradient = LinearGradient(
        colors: [Color(light: 0xF4EFE7, dark: 0x161210), Color(light: 0xEDE4D6, dark: 0x221C18)],
        startPoint: .top, endPoint: .bottom)
    // Near-flat bordeaux so every prior gradient call-site reads as one flat accent.
    static let brandGradient = LinearGradient(
        colors: [Color(light: 0x6E1E2E, dark: 0x9A3B4E), Color(light: 0x571623, dark: 0x7C2C3C)],
        startPoint: .top, endPoint: .bottom)
    static let whiteGradient = LinearGradient(
        colors: [paper, paper], startPoint: .top, endPoint: .bottom)
}

// MARK: - App state / localization

enum AppLanguage: String { case ar, en }

final class AppState: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "yaspa.lang") }
    }
    init() {
        if Runtime.isUITest {
            language = .en
        } else {
            let saved = UserDefaults.standard.string(forKey: "yaspa.lang")
            language = AppLanguage(rawValue: saved ?? "ar") ?? .ar
        }
    }
    var isAr: Bool { language == .ar }
    var layout: LayoutDirection { isAr ? .rightToLeft : .leftToRight }
    func t(_ ar: String, _ en: String) -> String { isAr ? ar : en }
    func toggle() { language = isAr ? .en : .ar }
    func money(_ v: Int) -> String { isAr ? "\(v) ﷼" : "SAR \(v)" }
}

// MARK: - Catalog

struct Massage: Identifiable, Hashable {
    let id: String
    let nameAr: String
    let nameEn: String
    let descAr: String
    let descEn: String
    let minutes: Int
    let price: Int
    let symbol: String
    let pressureAr: String
    let pressureEn: String
    let benefitsAr: [String]
    let benefitsEn: [String]
}

enum Catalog {
    static let all: [Massage] = [
        Massage(id: "swedish", nameAr: "المساج السويدي", nameEn: "Swedish Massage",
                descAr: "مساج استرخاء لطيف يحسّن الدورة الدموية ويذيب التوتر.",
                descEn: "A gentle relaxation massage that boosts circulation and melts tension.",
                minutes: 60, price: 199, symbol: "leaf.fill",
                pressureAr: "لطيف", pressureEn: "Gentle",
                benefitsAr: ["استرخاء عميق", "تحسين الدورة الدموية", "تخفيف التوتر"],
                benefitsEn: ["Deep relaxation", "Better circulation", "Stress relief"]),
        Massage(id: "deep", nameAr: "مساج الأنسجة العميقة", nameEn: "Deep Tissue",
                descAr: "ضغط أعمق يستهدف عقد العضلات والشدّ المزمن.",
                descEn: "Deeper pressure targeting muscle knots and chronic tightness.",
                minutes: 60, price: 249, symbol: "hand.raised.fill",
                pressureAr: "قوي", pressureEn: "Firm",
                benefitsAr: ["فكّ عقد العضلات", "تخفيف الألم المزمن", "تحسين الحركة"],
                benefitsEn: ["Releases knots", "Chronic pain relief", "Better mobility"]),
        Massage(id: "stone", nameAr: "مساج الأحجار الساخنة", nameEn: "Hot Stone",
                descAr: "أحجار بركانية دافئة ترخي العضلات بعمق وتهدّئ الحواس.",
                descEn: "Warm volcanic stones deeply relax muscles and calm the senses.",
                minutes: 75, price: 279, symbol: "flame.fill",
                pressureAr: "متوسط", pressureEn: "Medium",
                benefitsAr: ["استرخاء عضلي عميق", "دفء يهدّئ الأعصاب", "تحسين النوم"],
                benefitsEn: ["Deep muscle ease", "Soothing warmth", "Better sleep"]),
        Massage(id: "thai", nameAr: "المساج التايلندي", nameEn: "Thai Massage",
                descAr: "تمدّد ومطّ لطيف يعيد المرونة والطاقة لجسمكِ.",
                descEn: "Assisted stretching that restores flexibility and energy.",
                minutes: 90, price: 289, symbol: "figure.cooldown",
                pressureAr: "متوسط", pressureEn: "Medium",
                benefitsAr: ["زيادة المرونة", "تنشيط الطاقة", "إطالة العضلات"],
                benefitsEn: ["More flexibility", "Energy boost", "Muscle stretch"]),
        Massage(id: "aroma", nameAr: "العلاج بالزيوت العطرية", nameEn: "Aromatherapy",
                descAr: "زيوت عطرية مهدّئة لاسترخاءٍ عميق وصفاءٍ للذهن.",
                descEn: "Calming essential oils for deep relaxation and a clear mind.",
                minutes: 60, price: 219, symbol: "drop.fill",
                pressureAr: "لطيف", pressureEn: "Gentle",
                benefitsAr: ["صفاء ذهني", "استرخاء عميق", "تحسين المزاج"],
                benefitsEn: ["Clear mind", "Deep calm", "Mood lift"]),
        Massage(id: "foot", nameAr: "مساج القدمين الانعكاسي", nameEn: "Foot Reflexology",
                descAr: "ضغط على نقاط القدم يريح كامل الجسم ويجدّد نشاطكِ.",
                descEn: "Pressure-point foot work that relaxes the whole body.",
                minutes: 45, price: 149, symbol: "figure.walk",
                pressureAr: "متوسط", pressureEn: "Medium",
                benefitsAr: ["راحة كامل الجسم", "تنشيط الدورة", "تخفيف التعب"],
                benefitsEn: ["Whole-body relief", "Circulation", "Less fatigue"]),
    ]
}

// MARK: - Therapists

struct Therapist: Identifiable, Hashable {
    let id: String
    let nameAr: String
    let nameEn: String
    let rating: Double
    let years: Int
    let reviews: Int
    let specialtyAr: String
    let specialtyEn: String
    let bioAr: String
    let bioEn: String
}

enum Therapists {
    static let all: [Therapist] = [
        Therapist(id: "reem", nameAr: "ريم الغامدي", nameEn: "Reem G.", rating: 4.97, years: 7,
                  reviews: 214, specialtyAr: "السويدي والعطري", specialtyEn: "Swedish & Aromatherapy",
                  bioAr: "خبرة ٧ سنوات في المساج النسائي، تركّز على الاسترخاء العميق وراحتكِ التامة.",
                  bioEn: "7 years in women's massage, focused on deep relaxation and your total comfort."),
        Therapist(id: "hind", nameAr: "هند العتيبي", nameEn: "Hind A.", rating: 4.92, years: 5,
                  reviews: 168, specialtyAr: "الأنسجة العميقة", specialtyEn: "Deep Tissue",
                  bioAr: "متخصصة في علاج شدّ العضلات وآلام الظهر بلمسة احترافية.",
                  bioEn: "Specializes in muscle tension and back-pain relief with a professional touch."),
        Therapist(id: "sara", nameAr: "سارة القحطاني", nameEn: "Sara Q.", rating: 4.89, years: 4,
                  reviews: 132, specialtyAr: "الأحجار الساخنة والتايلندي", specialtyEn: "Hot Stone & Thai",
                  bioAr: "لمسة هادئة واحترافية تجدّد نشاطكِ وتمنحكِ صفاءً تامًا.",
                  bioEn: "A calm, professional touch that restores your energy and clears your mind."),
    ]
}

// MARK: - Social proof

struct Review: Identifiable, Hashable {
    let id = UUID()
    let nameAr: String
    let nameEn: String
    let rating: Int
    let textAr: String
    let textEn: String
}

enum Reviews {
    static let all: [Review] = [
        Review(nameAr: "نورة", nameEn: "Noura", rating: 5,
               textAr: "تجربة راقية وخصوصية تامة، المعالِجة محترفة جدًا.",
               textEn: "An elegant experience with total privacy — very professional."),
        Review(nameAr: "ليان", nameEn: "Layan", rating: 5,
               textAr: "حجزت بسهولة وجت المعالِجة بالوقت بالضبط.",
               textEn: "Booked in seconds and she arrived right on time."),
        Review(nameAr: "أمل", nameEn: "Amal", rating: 5,
               textAr: "أفضل مساج جربته بجدة، رجعت أحجز ثاني مرة.",
               textEn: "Best massage I've had in Jeddah — already booked again."),
        Review(nameAr: "دانة", nameEn: "Dana", rating: 5,
               textAr: "الأحجار الساخنة كانت خيالية، أنصح فيها.",
               textEn: "The hot stone was amazing, highly recommend."),
        Review(nameAr: "ريم", nameEn: "Reem", rating: 4,
               textAr: "نظافة وأدوات معقّمة، حسّيت بأمان. تأخرت شوي بس التجربة ممتازة.",
               textEn: "Clean, sealed tools — I felt safe. A little late but a great experience."),
        Review(nameAr: "شهد", nameEn: "Shahad", rating: 4,
               textAr: "مساج مريح وخصوصية عالية، بس ودّي بضغط أقوى شوي.",
               textEn: "Relaxing and private — I'd just like slightly firmer pressure."),
    ]
}

// MARK: - Pricing

enum Pricing {
    static let transport = 30
    static let vatRate = 0.15
    static func vat(_ price: Int) -> Int { Int((Double(price + transport) * vatRate).rounded()) }
    static func total(_ price: Int) -> Int { price + transport + vat(price) }
}

// MARK: - Scheduling

enum Scheduling {
    static func upcomingDays(_ count: Int = 14) -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    static let slotHours = Array(10...21)
    static func slots() -> [String] { slotHours.map { String(format: "%02d:00", $0) } }

    static func isAvailable(day: Date, time: String) -> Bool {
        if Runtime.isUITest { return true }
        let cal = Calendar.current
        let h = Int(time.prefix(2)) ?? 0
        // Never offer a time that already passed today. Real bookings are subtracted
        // separately by the taken_slots RPC (BookingView) — no more fake modulo.
        if cal.isDateInToday(day) && h <= cal.component(.hour, from: Date()) { return false }
        return true
    }
    static func longDate(_ date: Date, ar: Bool) -> String {
        fmt(ar ? "ar" : "en_US_POSIX", "EEEE، d MMM").string(from: date)
    }
    static func iso(_ date: Date) -> String { fmt("en_US_POSIX", "yyyy-MM-dd").string(from: date) }
    static func weekday(_ date: Date, ar: Bool) -> String { fmt(ar ? "ar" : "en", "EEE").string(from: date) }
    static func dayNumber(_ date: Date) -> String { fmt("en_US_POSIX", "d").string(from: date) }
    private static func fmt(_ locale: String, _ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: locale)
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }
}

// MARK: - Payment

enum PaymentMethod: String, Codable, Hashable, CaseIterable, Identifiable {
    case onArrival
    case applePay
    case card

    var id: String { rawValue }

    func label(ar: Bool) -> String {
        switch self {
        case .onArrival: return ar ? "الدفع عند الوصول" : "Pay on arrival"
        case .applePay:  return "Apple Pay"
        case .card:      return ar ? "بطاقة / مدى" : "Card / mada"
        }
    }

    func note(ar: Bool) -> String {
        switch self {
        case .onArrival: return ar ? "نقدًا أو بالبطاقة مع المعالِجة" : "Cash or card with your therapist"
        case .applePay:  return ar ? "دفع فوري وآمن" : "Instant, secure payment"
        case .card:      return ar ? "فيزا · ماستر · مدى" : "Visa · Mastercard · mada"
        }
    }

    var symbol: String {
        switch self {
        case .onArrival: return "banknote"
        case .applePay:  return "apple.logo"
        case .card:      return "creditcard"
        }
    }
}

// MARK: - Booking + store

/// Server-governed booking lifecycle (matches the Postgres booking_status enum exactly).
enum BookingStatus: String, Codable, Hashable {
    case pending, confirmed
    case onTheWay = "on_the_way"
    case completed, cancelled
    case noShow = "no_show"

    func label(ar: Bool) -> String {
        switch self {
        case .pending:   return ar ? "بانتظار التأكيد" : "Pending"
        case .confirmed: return ar ? "مؤكّد" : "Confirmed"
        case .onTheWay:  return ar ? "في الطريق إليكِ" : "On the way"
        case .completed: return ar ? "اكتمل" : "Completed"
        case .cancelled: return ar ? "ملغى" : "Cancelled"
        case .noShow:    return ar ? "لم يحضر" : "No-show"
        }
    }
    var isActive: Bool { self == .pending || self == .confirmed || self == .onTheWay }
    /// Progress over [Confirmed, On the way, Completed]; -1 when cancelled/no-show.
    var timelineStep: Int {
        switch self {
        case .pending, .confirmed: return 0
        case .onTheWay:            return 1
        case .completed:           return 2
        default:                   return -1
        }
    }
}

struct Booking: Identifiable, Codable, Hashable {
    var id = UUID()
    var massageId: String
    var massageNameAr: String
    var massageNameEn: String
    var minutes: Int
    var price: Int
    var dateISO: String
    var time: String
    var therapistName: String
    var name: String
    var district: String
    var notes: String
    var paymentMethod: PaymentMethod? = .onArrival
    var status: BookingStatus? = .confirmed
    var createdAt = Date()
}

final class BookingStore: ObservableObject {
    @Published private(set) var bookings: [Booking] = []
    private let key = "yaspa.bookings.v1"

    init() { load() }

    func add(_ b: Booking) { bookings.insert(b, at: 0); save() }
    func remove(_ b: Booking) { bookings.removeAll { $0.id == b.id }; save() }

    /// Merge cloud bookings into the on-device list, deduped by id. Bookings share
    /// the same id on cloud and device, so this never creates duplicates.
    func merge(_ incoming: [Booking]) {
        guard !incoming.isEmpty else { return }
        let existing = Set(bookings.map(\.id))
        let fresh = incoming.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return }
        bookings.append(contentsOf: fresh)
        bookings.sort { ($0.dateISO, $0.time) > ($1.dateISO, $1.time) }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Booking].self, from: data) else { return }
        bookings = decoded
    }
    private func save() {
        if let data = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
