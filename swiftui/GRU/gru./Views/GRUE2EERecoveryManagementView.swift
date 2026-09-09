import SwiftUI
import UIKit

@MainActor
struct GRUE2EERecoveryManagementView: View {
    @State private var status = GRUE2EERecoveryStatus(
        hasLocalIdentity: false,
        hasSynchronizedRecoveryKey: false
    )
    @State private var recoveryCode: String?
    @State private var loading = false
    @State private var errorText: String?
    @State private var copied = false

    var body: some View {
        List {
            Section("Состояние") {
                statusRow(
                    title: "Локальная E2EE-личность",
                    ready: status.hasLocalIdentity
                )
                statusRow(
                    title: "Ключ восстановления в iCloud Keychain",
                    ready: status.hasSynchronizedRecoveryKey
                )
            }

            Section {
                Button {
                    Task { await refreshBackup() }
                } label: {
                    Label(
                        "Создать / обновить резервную копию",
                        systemImage: "arrow.triangle.2.circlepath.icloud.fill"
                    )
                }
                .disabled(loading || !status.hasLocalIdentity)

                Button {
                    revealRecoveryCode()
                } label: {
                    Label(
                        "Показать recovery code",
                        systemImage: "key.viewfinder"
                    )
                }
                .disabled(loading || !status.hasSynchronizedRecoveryKey)
            } header: {
                Text("Восстановление")
            } footer: {
                Text(
                    "Backend хранит только зашифрованный backup. Recovery key и приватные X25519/Ed25519 ключи серверу не передаются."
                )
            }

            if let recoveryCode {
                Section("Recovery code") {
                    Text(recoveryCode)
                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        UIPasteboard.general.string = recoveryCode
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            copied = false
                        }
                    } label: {
                        Label(
                            copied ? "Скопировано" : "Скопировать",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                    }
                }
            }

            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .overlay {
            if loading {
                ProgressView("Обновляем защиту…")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("Восстановление E2EE")
        .navigationBarTitleDisplayMode(.inline)
        .task { refreshStatus() }
    }

    private func statusRow(title: String, ready: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ready ? .green : .orange)
        }
    }

    private func refreshStatus() {
        guard let userID = TokenStorage.shared.userID, !userID.isEmpty else {
            status = GRUE2EERecoveryStatus(
                hasLocalIdentity: false,
                hasSynchronizedRecoveryKey: false
            )
            return
        }
        status = GRUE2EERecoveryService.shared.status(userID: userID)
    }

    private func refreshBackup() async {
        guard let token = TokenStorage.shared.token, !token.isEmpty,
              let userID = TokenStorage.shared.userID, !userID.isEmpty else {
            errorText = "Сессия недоступна."
            return
        }

        loading = true
        errorText = nil
        defer { loading = false }

        do {
            let created = try await GRUE2EERecoveryService.shared.createOrRefreshBackup(
                token: token,
                userID: userID
            )
            recoveryCode = created.recoveryCode
            refreshStatus()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func revealRecoveryCode() {
        guard let userID = TokenStorage.shared.userID, !userID.isEmpty else {
            errorText = "Сессия недоступна."
            return
        }

        do {
            recoveryCode = try GRUE2EERecoveryService.shared.exportedRecoveryCode(
                userID: userID
            )
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
