import SwiftUI
import UIKit

struct LoginView: View {
    let onLogin: () -> Void

    @State private var viewModel = LoginViewModel()
    @State private var isRegister = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            VStack(spacing: 24) {
                Spacer()

                Text("gru.")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 16) {
                    GRUNoCredentialTextField(
                        placeholder: GRUL10n.text("Phone"),
                        text: $viewModel.phone,
                        isSecure: false,
                        keyboardType: .phonePad
                    )
                    .frame(height: 52)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    GRUNoCredentialTextField(
                        placeholder: GRUL10n.text("Password"),
                        text: $viewModel.password,
                        isSecure: true,
                        keyboardType: .default
                    )
                    .frame(height: 52)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if isRegister {
                        GRUNoCredentialTextField(
                            placeholder: GRUL10n.text("Nickname"),
                            text: $viewModel.nickname,
                            isSecure: false,
                            keyboardType: .default
                        )
                        .frame(height: 52)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                }

                Button {
                    dismissKeyboard()

                    Task {
                        let didAuthenticate: Bool
                        if isRegister {
                            didAuthenticate = await viewModel.register()
                        } else {
                            didAuthenticate = await viewModel.login()
                        }

                        if didAuthenticate {
                            onLogin()
                        }
                    }
                } label: {
                    if viewModel.loading {
                        ProgressView()
                    } else {
                        Text(
                            GRUL10n.text(
                                isRegister
                                    ? "Create account"
                                    : "Login"
                            )
                        )
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button {
                    dismissKeyboard()
                    isRegister.toggle()
                } label: {
                    Text(
                        GRUL10n.text(
                            isRegister
                                ? "Already have an account?"
                                : "Create account"
                        )
                    )
                    .foregroundStyle(.gray)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            viewModel.phone = ""
            viewModel.password = ""
            viewModel.nickname = ""

            dismissKeyboard()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                dismissKeyboard()
            }
        }
        .onChange(of: isRegister) { _, _ in
            dismissKeyboard()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

/// UIKit-backed auth field that deliberately opts out of semantic credential
/// content types. iOS may still render its own QuickType/password UI after an
/// explicit tap, but the app itself never requests username/password/OTP
/// AutoFill and never becomes first responder programmatically.
private struct GRUNoCredentialTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)

        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )

        textField.placeholder = placeholder
        textField.textColor = .white
        textField.tintColor = .white
        textField.font = .systemFont(ofSize: 17)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.keyboardType = keyboardType
        textField.returnKeyType = .done
        textField.isSecureTextEntry = isSecure

        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no

        textField.textContentType = nil
        textField.passwordRules = nil

        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.42)
            ]
        )

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.isSecureTextEntry = isSecure
        uiView.keyboardType = keyboardType
        uiView.textContentType = nil
        uiView.passwordRules = nil
        uiView.placeholder = placeholder
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor:
                    UIColor.white.withAlphaComponent(0.42)
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

#Preview {
    LoginView(onLogin: {})
}
