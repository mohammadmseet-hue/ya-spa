import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var auth: AuthStore
    @State private var phone = ""
    @State private var code = ""

    var body: some View {
        ZStack {
            Brand.heroGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 56)).foregroundStyle(Brand.pinkDeep)
                Text(app.t("يا سبا", "Ya Spa"))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.pinkDeep)
                Text(app.t("المساج النسائي يجيكِ البيت", "Women's massage, at your home"))
                    .font(.subheadline).foregroundStyle(Brand.muted)
                    .padding(.bottom, 6)

                if auth.codeSent { codeStep } else { phoneStep }

                if let e = auth.errorMessage {
                    Text(e).font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Spacer(); Spacer()
                Text(app.t("نساء فقط · معتمدات · موثّقات",
                           "Women only · Certified · Verified"))
                    .font(.caption2).foregroundStyle(Brand.muted)
            }
            .padding(24)
            .frame(maxWidth: 460)
        }
    }

    private var phoneStep: some View {
        VStack(spacing: 14) {
            Text(app.t("سجّلي الدخول برقم جوالكِ", "Sign in with your phone"))
                .font(.headline).foregroundStyle(Brand.ink)
            HStack(spacing: 8) {
                Text("+966").font(.headline).foregroundStyle(Brand.muted)
                TextField("5X XXX XXXX", text: $phone)
                    .keyboardType(.numberPad)
                    .font(.headline)
            }
            .padding(16)
            .background(Brand.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await auth.sendOTP(phone: phone) }
            } label: {
                if auth.sending { ProgressView().tint(.white) }
                else { Text(app.t("أرسلي الرمز", "Send code")) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(phone.filter(\.isNumber).count < 8 || auth.sending)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            Text(app.t("أدخلي الرمز المُرسَل إليكِ", "Enter the code we texted you"))
                .font(.headline).foregroundStyle(Brand.ink)
            TextField(app.t("رمز من ٦ أرقام", "6-digit code"), text: $code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(.title3, design: .rounded))
                .padding(16)
                .background(Brand.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await auth.verify(code: code) }
            } label: {
                if auth.verifying { ProgressView().tint(.white) }
                else { Text(app.t("تأكيد", "Verify")) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(code.filter(\.isNumber).count < 4 || auth.verifying)

            Button(app.t("تغيير الرقم", "Change number")) {
                auth.codeSent = false
                auth.errorMessage = nil
            }
            .font(.footnote).foregroundStyle(Brand.muted)
        }
    }
}
