import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

@MainActor
struct GRUE2EESecurityCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chatService = ChatService.shared

    private var peers: [User] {
        var seen: Set<String> = []
        var result: [User] = []
        let currentID = chatService.currentUser.id

        for chat in chatService.chats {
            for user in chat.users where user.id != currentID && !user.isBot {
                guard let serverID = user.serverID, !serverID.isEmpty else { continue }
                if seen.insert(serverID).inserted {
                    result.append(user)
                }
            }
        }

        return result.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GRUE2EERecoveryManagementView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(GRUColors.accent)
                                .frame(width: 34, height: 34)
                                .background(
                                    GRUColors.accent.opacity(0.12),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Восстановление E2EE")
                                    .font(.headline)
                                Text("Смена iPhone, переустановка и recovery code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Моя защита")
                } footer: {
                    Text(
                        "Приватные X25519/Ed25519 ключи не хранятся на backend. Сервер получает только зашифрованный recovery backup."
                    )
                }

                Section("Проверка контактов") {
                    if peers.isEmpty {
                        Label(
                            "Создай личный чат — здесь появится проверка E2EE-ключей.",
                            systemImage: "lock.shield"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(peers) { peer in
                            NavigationLink {
                                GRUE2EEPeerVerificationView(peer: peer)
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(user: peer, size: 42)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(peer.displayName)
                                            .font(.headline)
                                        Text("Проверить защищённый ключ")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "lock.shield")
                                        .foregroundStyle(GRUColors.accent)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Защита gru.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

@MainActor
private struct GRUE2EEPeerVerificationView: View {
    let peer: User

    @State private var identity: GRUE2EEPublicIdentity?
    @State private var safetyCode: GRUE2EESafetyCode?
    @State private var trustState: GRUE2EETrustState?
    @State private var explicitlyVerified = false
    @State private var loading = true
    @State private var errorText: String?
    @State private var copied = false

    private var peerID: String? {
        peer.serverID?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AvatarView(user: peer, size: 72)

                VStack(spacing: 4) {
                    Text(peer.displayName)
                        .font(.title2.bold())
                    statusLabel
                }

                if loading {
                    ProgressView("Проверяем ключи…")
                        .padding(.top, 24)
                } else if let errorText {
                    securityCard {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } else if let safetyCode, let identity {
                    verificationContent(safetyCode: safetyCode, identity: identity)
                }
            }
            .padding(20)
        }
        .navigationTitle("Проверка E2EE")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadIdentity() }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if explicitlyVerified {
            Label("Личность ключа подтверждена", systemImage: "checkmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else if case .keyChanged? = trustState {
            Label("Ключ изменился — требуется проверка", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        } else {
            Label("E2EE включено, ключ ещё не сверен вручную", systemImage: "lock.shield")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func verificationContent(
        safetyCode: GRUE2EESafetyCode,
        identity: GRUE2EEPublicIdentity
    ) -> some View {
        securityCard {
            VStack(spacing: 14) {
                Text("SAFETY NUMBER")
                    .font(.caption.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)

                Text(safetyCode.grouped)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = safetyCode.digits
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        copied = false
                    }
                } label: {
                    Label(
                        copied ? "Скопировано" : "Скопировать код",
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.bordered)
            }
        }

        if let image = qrImage(payload: safetyCode.qrPayload) {
            securityCard {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                        .padding(10)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Сканируйте QR друг у друга или сравните safety number по другому каналу — например лично или по звонку.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }

        securityCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fingerprint identity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(identity.trustFingerprint)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Button {
            verify(identity: identity)
        } label: {
            Label(
                explicitlyVerified ? "Ключ подтверждён" : "Коды совпадают — подтвердить",
                systemImage: explicitlyVerified ? "checkmark.shield.fill" : "checkmark.shield"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .tint(GRUColors.accent)
        .disabled(explicitlyVerified)

        Text("Подтверждай только после реального сравнения. Эта кнопка может принять новый ключ после его смены, поэтому не нажимай её вслепую.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func securityCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(GRUColors.card.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func loadIdentity() async {
        loading = true
        errorText = nil
        defer { loading = false }

        guard let peerID, !peerID.isEmpty,
              let currentUserID = TokenStorage.shared.userID,
              !currentUserID.isEmpty,
              let token = TokenStorage.shared.token,
              !token.isEmpty else {
            errorText = "Сессия или ID собеседника недоступны."
            return
        }

        do {
            let response = try await E2EEAPIService.shared.identity(for: peerID, token: token)
            let peerIdentity = response.identity
            let code = try GRUE2EE.shared.safetyCode(
                currentUserID: currentUserID,
                peerUserID: peerID,
                peerIdentity: peerIdentity
            )

            identity = peerIdentity
            safetyCode = code
            trustState = GRUE2EE.shared.trustState(for: peerID, identity: peerIdentity)
            explicitlyVerified = GRUE2EEVerificationStore.shared.isVerified(
                userID: peerID,
                identity: peerIdentity
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func verify(identity: GRUE2EEPublicIdentity) {
        guard let peerID else { return }
        do {
            try GRUE2EE.shared.trust(identity: identity, for: peerID)
            try GRUE2EEVerificationStore.shared.verify(userID: peerID, identity: identity)
            trustState = .trusted
            explicitlyVerified = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func qrImage(payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
