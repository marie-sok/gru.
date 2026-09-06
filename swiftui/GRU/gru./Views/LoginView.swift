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
                        placeholder: "Phone",
                        text: $viewModel.phone,
                        isSecure: false,
                        keyboardType: .phonePad,
                        suppressCredentialAutofill: true
                    )
                    .frame(height: 52)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    GRUNoCredentialTextField(
                        placeholder: "Password",
                        text: $viewModel.password,
                        isSecure: true,
                        keyboardType: .default,
                        suppressCredentialAutofill: true
                    )
                    .frame(height: 52)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if isRegister {
                        GRUNoCredentialTextField(
                            placeholder: "Nickname",
                            text: $viewModel.nickname,
                            isSecure: false,
                            keyboardType: .default,
                            suppressCredentialAutofill: false
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
                        Text(isRegister ? "Create account" : "Login")
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
                        isRegister
                            ? "Already have an account?"
                            : "Create account"
                    )
                    .foregroundStyle(.gray)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Login always opens with a clean, unfocused form. In particular,
            // do not allow an old iOS Password AutoFill credential such as
            // the previously suggested "222" account to pre-populate fields.
            viewModel.phone = ""
            viewModel.password = ""
            viewModel.nickname = ""

            dismissKeyboard()

            // iOS can restore a responder one run-loop later while rebuilding
            // the screen. Resign once more after that restoration window.
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

/// UIKit-backed field used only on the auth screen.
/// It deliberately avoids the username/password content types that trigger
/// Password AutoFill. `.oneTimeCode` is used for credential fields because it
/// prevents iOS from treating them as saved login/password destinations while
/// preserving normal manual typing and secure entry.
private struct GRUNoCredentialTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let suppressCredentialAutofill: Bool

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

        if suppressCredentialAutofill {
            textField.textContentType = .oneTimeCode
            textField.passwordRules = nil
        } else {
            textField.textContentType = nil
        }

        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.42)
            ]
        )

        // Never call becomeFirstResponder here. The keyboard must appear only
        // after an explicit user tap.
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.isSecureTextEntry = isSecure
        uiView.keyboardType = keyboardType

        if suppressCredentialAutofill {
            uiView.textContentType = .oneTimeCode
        } else {
            uiView.textContentType = nil
        }
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
