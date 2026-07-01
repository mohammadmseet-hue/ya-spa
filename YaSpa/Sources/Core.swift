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
}

enum Brand {
    static let pinkDeep = Color(hex: 0x9E2B52)
    static let pink     = Color(hex: 0xE45C86)
    static let pinkSoft = Color(hex: 0xF7AEC4)
    static let gold     = Color(hex: 0xC9A24B)
    static let bg       = Color(hex: 0xFFF5F7)
    static let bg2      = Color(hex: 0xFDE8EE)
    static let ink      = Color(hex: 0x3A2230)
    static let muted    = Color(hex: 0x7A5966)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0xFFF5F7), Color(hex: 0xFDE8EE)],
        startPoint: .top, endPoint: .bottom)
    static let brandGradient = LinearGradient(
        colors: [pink, pinkDeep], startPoint: .top, endPoint: .bottom)
    static let whiteGradient = LinearGradient(
        colors: [.white, .white], startPoint: .top, endPoint: .bottom)
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
}

enum Catalog {
    static let all: [Massage] = [
        Massage(id: "swedish", nameAr: "المساج السويدي", nameEn: "Swedish Massage",
                descAr: "مساج استرخاء لطيف يحسّن الدورة الدموية ويذيب التوتر.",
                descEn: "A gentle relaxation massage that boosts circulation and melts tension.",
                minutes: 60, price: 199, symbol: "leaf.fill"),
        Massage(id: "deep", nameAr: "مساج الأنسجة العميقة", nameEn: "Deep Tissue",
                descAr: "ضغط أعمق يستهدف عقد العضلات والشدّ المزمن.",
                descEn: "Deeper pressure targeting muscle knots and chronic tightness.",
                minutes: 60, price: 249, symbol: "hand.raised.fill"),
        Massage(id: "stone", nameAr: "مساج الأحجار الساخنة", nameEn: "Hot Stone",
                descAr: "أحجار بركانية دافئة ترخي العضلات بعمق وتهدّئ الحواس.",
                descEn: "Warm volcanic stones deeply relax muscles and calm the senses.",
                minutes: 75, price: 279, symbol: "flame.fill"),
        Massage(id: "thai", nameAr: "المساج التايلندي", nameEn: "Thai Massage",
                descAr: "تمدّد ومطّ لطيف يعيد المرونة والطاقة لجسمكِ.",
                descEn: "Assisted stretching that restores flexibility and energy.",
                minutes: 90, price: 289, symbol: "figure.cooldown"),
        Massage(id: "aroma", nameAr: "العلاج بالزيوت العطرية", nameEn: "Aromatherapy",
                descAr: "زيوت عطرية مهدّئة لاسترخاءٍ عميق وصفاءٍ للذهن.",
                descEn: "Calming essential oils for deep relaxation and a clear mind.",
                minutes: 60, price: 219, symbol: "drop.fill"),
        Massage(id: "foot", nameAr: "مساج القدمين الانعكاسي", nameEn: "Foot Reflexology",
                descAr: "ضغط على نقاط القدم يريح كامل الجسم ويجدّد نشاطكِ.",
                descEn: "Pressure-point foot work that relaxes the whole body.",
                minutes: 45, price: 149, symbol: "figure.walk"),
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
        let d = Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 0
        let h = Int(time.prefix(2)) ?? 0
        return (d + h) % 4 != 0
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

// MARK: - Booking + store

struct Booking: Identifiable, Codable, Hashable {
    var id = UUID()
    var massageId: String
    var massageNameAr: String
    var massageNameEn: String
    var minutes: Int
    var price: Int
    var dateISO: String
    var time: String
    var name: String
    var district: String
    var notes: String
    var createdAt = Date()
}

final class BookingStore: ObservableObject {
    @Published private(set) var bookings: [Booking] = []
    private let key = "yaspa.bookings.v1"

    init() { load() }

    func add(_ b: Booking) { bookings.insert(b, at: 0); save() }
    func remove(_ b: Booking) { bookings.removeAll { $0.id == b.id }; save() }

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
