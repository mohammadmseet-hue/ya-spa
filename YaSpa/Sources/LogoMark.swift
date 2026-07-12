import SwiftUI

/// Ya Spa brand-mark colors — a natural-spa palette: sugar off-white ground,
/// grass-green jasmine, deep botanical-green mihrab arch, antique-gold center.
/// Fixed (a logo keeps its colors regardless of app light/dusk).
enum Logo {
    static let sugar  = Color(hex: 0xF7F3E9)   // sugar off-white background
    static let grass  = Color(hex: 0x7BA23F)   // grass-green petals
    static let grass2 = Color(hex: 0x8FB755)   // lighter grass (petal top)
    static let forest = Color(hex: 0x2E4B34)   // deep green arch
    static let forest2 = Color(hex: 0x213827)  // arch shadow
    static let gold   = Color(hex: 0xC9A15E)   // antique-gold center + hairline

    static var archGradient: LinearGradient {
        LinearGradient(colors: [forest, forest2], startPoint: .top, endPoint: .bottom)
    }
    static var petalGradient: LinearGradient {
        LinearGradient(colors: [grass2, grass], startPoint: .top, endPoint: .bottom)
    }
}

/// The Ya Spa mark — a mihrab (hammam) arch cradling a jasmine bloom — drawn in
/// SwiftUI so it's crisp at any size. Reuses ArchShape.
struct YaSpaLogoMark: View {
    var height: CGFloat = 120
    var body: some View {
        let w = height * 0.74
        ZStack {
            ArchShape().fill(Logo.archGradient)
            ArchShape().stroke(Logo.gold.opacity(0.9), lineWidth: max(1, height * 0.012))
            JasmineBloom()
                .frame(width: w * 0.60, height: w * 0.60)
                .offset(y: -height * 0.015)
        }
        .frame(width: w, height: height)
        .shadow(color: Logo.forest.opacity(0.22), radius: height * 0.16, y: height * 0.07)
    }
}

/// Five grass-green petals radiating from a gold center.
struct JasmineBloom: View {
    var petal: LinearGradient = Logo.petalGradient
    var center: Color = Logo.gold
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Ellipse()
                        .fill(petal)
                        .frame(width: s * 0.30, height: s * 0.52)
                        .offset(y: -s * 0.20)                      // tip toward center
                        .rotationEffect(.degrees(Double(i) * 72))  // radiate around layout center
                }
                Circle().fill(center).frame(width: s * 0.20, height: s * 0.20)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}
