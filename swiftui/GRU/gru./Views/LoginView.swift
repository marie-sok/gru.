import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void

    @State private var viewModel = LoginViewModel()
    @State private var isRegister = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("gru.")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 16) {
                    TextField("Phone", text: $viewModel.phone)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if isRegister {
                        TextField("Nickname", text: $viewModel.nickname)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                }

                Button {
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
    }
}

#Preview {
    LoginView(onLogin: {})
}
