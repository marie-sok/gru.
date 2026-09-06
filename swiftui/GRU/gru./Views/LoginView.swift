import SwiftUI
import UIKit

struct LoginView: View {
    let onLogin: () -> Void

    @State private var viewModel = LoginViewModel()
    @State private var isRegister = false

    @AppStorage(GRUAppLanguage.storageKey)
    private var languageRaw =
        GRUAppLanguage.defaultLanguage.rawValue

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            ScrollView {
                VStack(spacing: 0) {
                    languageSwitcher
                        .padding(.top, 18)

                    Spacer()
                        .frame(height: 74)

                    Text("gru.")
                        .font(
                            .system(
                                size: 44,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)

                    VStack(spacing: 8) {
                        Text(
                            GRUL10n.text(
                                isRegister
                                    ? "Create your gru. account"
                                    : "Sign in to gru."
                            )
                        )
                        .font(
                            .system(
                                size: 22,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                        Text(
                            GRUL10n.text(
                                isRegister
                                    ? "Register with your phone number, password and nickname."
                                    : "Use your phone number and password."
                            )
                        )
                        .font(
                            .system(
                                size: 13,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.55)
                        )
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)

                    VStack(spacing: 13) {
                        authField(
                            placeholder:
                                GRUL10n.text(
                                    "Phone number"
                                ),
                            text:
                                $viewModel.phone,
                            secure:
                                false,
                            keyboard:
                                .phonePad,
                            icon:
                                "phone.fill"
                        )

                        HStack(spacing: 7) {
                            Image(
                                systemName:
                                    "globe"
                            )
                            .font(
                                .system(
                                    size: 10,
                                    weight: .bold
                                )
                            )

                            Text(
                                GRUL10n.text(
                                    "Include country code, for example +7 999 123-45-67."
                                )
                            )
                        }
                        .font(
                            .system(
                                size: 10,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.40)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(.horizontal, 4)

                        authField(
                            placeholder:
                                GRUL10n.text(
                                    "Password"
                                ),
                            text:
                                $viewModel.password,
                            secure:
                                true,
                            keyboard:
                                .default,
                            icon:
                                "lock.fill"
                        )

                        if isRegister {
                            authField(
                                placeholder:
                                    GRUL10n.text(
                                        "Nickname"
                                    ),
                                text:
                                    $viewModel.nickname,
                                secure:
                                    false,
                                keyboard:
                                    .default,
                                icon:
                                    "person.fill"
                            )
                            .transition(
                                .move(edge: .top)
                                    .combined(
                                        with:
                                            .opacity
                                    )
                            )
                        }
                    }
                    .padding(.top, 24)

                    Text(
                        GRUL10n.text(
                            "Your phone number is your sign-in ID."
                        )
                    )
                    .font(
                        .system(
                            size: 11,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.42)
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(.top, 10)
                    .padding(.horizontal, 4)

                    if let error =
                        viewModel.error
                    {
                        HStack(
                            alignment: .top,
                            spacing: 8
                        ) {
                            Image(
                                systemName:
                                    "exclamationmark.circle.fill"
                            )

                            Text(error)
                                .fixedSize(
                                    horizontal:
                                        false,
                                    vertical:
                                        true
                                )
                        }
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            .red.opacity(0.92)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(12)
                        .background(
                            Color.red.opacity(0.08),
                            in:
                                RoundedRectangle(
                                    cornerRadius: 13,
                                    style: .continuous
                                )
                        )
                        .padding(.top, 14)
                    }

                    Button {
                        authenticate()
                    } label: {
                        ZStack {
                            if viewModel.loading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(
                                    GRUL10n.text(
                                        isRegister
                                            ? "Register"
                                            : "Sign in"
                                    )
                                )
                                .font(
                                    .system(
                                        size: 15,
                                        weight: .black,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(
                                    .black
                                )
                            }
                        }
                        .frame(
                            maxWidth: .infinity
                        )
                        .frame(height: 52)
                        .background(
                            Color.white,
                            in:
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        isRegister
                            ? !viewModel.canRegister
                            : !viewModel.canLogin
                    )
                    .opacity(
                        (
                            isRegister
                                ? viewModel.canRegister
                                : viewModel.canLogin
                        )
                            ? 1
                            : 0.52
                    )
                    .padding(.top, 20)

                    Button {
                        dismissKeyboard()

                        withAnimation(
                            .easeInOut(
                                duration: 0.18
                            )
                        ) {
                            isRegister.toggle()
                        }

                        viewModel.error = nil
                    } label: {
                        HStack(spacing: 5) {
                            Text(
                                GRUL10n.text(
                                    isRegister
                                        ? "Already have an account?"
                                        : "No account yet?"
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.52)
                            )

                            Text(
                                GRUL10n.text(
                                    isRegister
                                        ? "Sign in"
                                        : "Register"
                                )
                            )
                            .foregroundStyle(
                                .white
                            )
                            .fontWeight(.bold)
                        }
                        .font(
                            .system(
                                size: 13,
                                design: .rounded
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 17)

                    Spacer()
                        .frame(height: 48)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(
                .interactively
            )
        }
        .onAppear {
            viewModel.phone = ""
            viewModel.password = ""
            viewModel.nickname = ""

            dismissKeyboard()

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now()
                        + 0.30
                ) {
                    dismissKeyboard()
                }
        }
        .onChange(of: isRegister) {
            _, _ in

            dismissKeyboard()
        }
    }

    private var languageSwitcher:
        some View
    {
        HStack(spacing: 4) {
            languageButton(
                .russian
            )

            languageButton(
                .english
            )
        }
        .padding(4)
        .background(
            Color.white.opacity(0.07),
            in: Capsule()
        )
        .frame(
            maxWidth: .infinity,
            alignment: .trailing
        )
    }

    private func languageButton(
        _ language:
            GRUAppLanguage
    ) -> some View {
        let selected =
            languageRaw
            == language.rawValue

        return Button {
            dismissKeyboard()
            languageRaw =
                language.rawValue
            viewModel.error =
                nil
        } label: {
            Text(language.badge)
                .font(
                    .system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    selected
                        ? .black
                        : .white.opacity(0.58)
                )
                .frame(
                    width: 38,
                    height: 27
                )
                .background(
                    selected
                        ? Color.white
                        : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            language.nativeTitle
        )
    }

    private func authField(
        placeholder: String,
        text: Binding<String>,
        secure: Bool,
        keyboard: UIKeyboardType,
        icon: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(
                systemName: icon
            )
            .font(
                .system(
                    size: 13,
                    weight: .bold
                )
            )
            .foregroundStyle(
                .white.opacity(0.48)
            )
            .frame(width: 18)

            GRUNoCredentialTextField(
                placeholder:
                    placeholder,
                text:
                    text,
                isSecure:
                    secure,
                keyboardType:
                    keyboard
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            Color.white.opacity(0.075),
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.06),
                lineWidth: 1
            )
        }
    }

    private func authenticate() {
        dismissKeyboard()

        Task {
            let didAuthenticate:
                Bool

            if isRegister {
                didAuthenticate =
                    await viewModel
                        .register()
            } else {
                didAuthenticate =
                    await viewModel
                        .login()
            }

            if didAuthenticate {
                onLogin()
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared
            .sendAction(
                #selector(
                    UIResponder
                        .resignFirstResponder
                ),
                to: nil,
                from: nil,
                for: nil
            )
    }
}

private struct GRUNoCredentialTextField:
    UIViewRepresentable
{
    let placeholder: String

    @Binding
    var text: String

    let isSecure: Bool
    let keyboardType: UIKeyboardType

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator(
            text: $text
        )
    }

    func makeUIView(
        context: Context
    ) -> UITextField {
        let textField =
            UITextField(
                frame: .zero
            )

        textField.delegate =
            context.coordinator

        textField.addTarget(
            context.coordinator,
            action:
                #selector(
                    Coordinator
                        .textDidChange(_:)
                ),
            for:
                .editingChanged
        )

        textField.placeholder =
            placeholder

        textField.textColor =
            .white

        textField.tintColor =
            .white

        textField.font =
            .systemFont(
                ofSize: 16
            )

        textField.backgroundColor =
            .clear

        textField.borderStyle =
            .none

        textField.keyboardType =
            keyboardType

        textField.returnKeyType =
            .done

        textField.isSecureTextEntry =
            isSecure

        textField.autocorrectionType =
            .no

        textField.autocapitalizationType =
            .none

        textField.spellCheckingType =
            .no

        textField.smartDashesType =
            .no

        textField.smartQuotesType =
            .no

        textField.smartInsertDeleteType =
            .no

        // Keep auth fields outside iOS credential/OTP semantics.
        textField.textContentType =
            nil

        textField.passwordRules =
            nil

        applyPlaceholder(
            to: textField
        )

        return textField
    }

    func updateUIView(
        _ uiView: UITextField,
        context: Context
    ) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.isSecureTextEntry =
            isSecure

        uiView.keyboardType =
            keyboardType

        uiView.textContentType =
            nil

        uiView.passwordRules =
            nil

        uiView.placeholder =
            placeholder

        applyPlaceholder(
            to: uiView
        )
    }

    private func applyPlaceholder(
        to textField: UITextField
    ) {
        textField.attributedPlaceholder =
            NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor:
                        UIColor.white
                            .withAlphaComponent(
                                0.42
                            )
                ]
            )
    }

    final class Coordinator:
        NSObject,
        UITextFieldDelegate
    {
        @Binding
        private var text: String

        init(
            text:
                Binding<String>
        ) {
            _text = text
        }

        @objc
        func textDidChange(
            _ sender: UITextField
        ) {
            text =
                sender.text
                ?? ""
        }

        func textFieldShouldReturn(
            _ textField:
                UITextField
        ) -> Bool {
            textField
                .resignFirstResponder()

            return true
        }
    }
}

#Preview {
    LoginView(
        onLogin: {}
    )
}
