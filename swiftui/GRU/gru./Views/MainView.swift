import SwiftUI

@MainActor
struct MainView: View {
    @State private var selectedTab: AppTab = .chats
    @State private var isChatPresented = false
    @State private var isAgentPresented = false
    @State private var showBotTestLab = false
    @State private var showConnectivityDiagnostics = false
    @State private var showE2EESecurityCenter = false
    @StateObject private var connectivity = GRUConnectivityCenter.shared

    var body: some View {
        ZStack {
            GRUAppBackdrop()
            selectedContent
        }
        .overlay(alignment: .top) {
            if !isChatPresented && !isAgentPresented {
                GRUConnectionBanner(
                    center: connectivity,
                    onOpenDiagnostics: {
                        showConnectivityDiagnostics = true
                    }
                )
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .transition(
                    .move(edge: .top)
                        .combined(with: .opacity)
                )
                .animation(
                    .easeInOut(duration: 0.20),
                    value: connectivity.bannerTitle
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isChatPresented && !isAgentPresented {
                GRUTabBar(selectedTab: $selectedTab)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            connectivity.start()
        }
        .sheet(isPresented: $showBotTestLab) {
            NavigationStack {
                GRUBetaTestChatView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Готово") {
                                showBotTestLab = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showConnectivityDiagnostics) {
            NavigationStack {
                GRUConnectivityDiagnosticsView(center: connectivity)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Готово") {
                                showConnectivityDiagnostics = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showE2EESecurityCenter) {
            GRUE2EESecurityCenterView()
        }
        .onChange(of: selectedTab) { _, _ in
            if isChatPresented {
                isChatPresented = false
            }
            if isAgentPresented {
                isAgentPresented = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("gru.agent.presentation.changed"))) { note in
            guard let presented = note.object as? Bool else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isAgentPresented = presented
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenChats)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = .chats
                isChatPresented = false
                isAgentPresented = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenContacts)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = .contacts
                isChatPresented = false
                isAgentPresented = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = .settings
                isChatPresented = false
                isAgentPresented = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenTestLab)) { _ in
            selectedTab = .chats
            isChatPresented = false
            isAgentPresented = false
            showBotTestLab = true
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        if selectedTab == .contacts {
            ContactsView()
        } else if selectedTab == .settings {
            ZStack(alignment: .bottomTrailing) {
                GRUReleaseSettingsView()

                Button {
                    showE2EESecurityCenter = true
                } label: {
                    Label("Защита E2EE", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(GRUColors.accent.opacity(0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(GRUColors.accent)
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .accessibilityLabel("Открыть центр проверки E2EE")
            }
        } else {
            BetaChatListView(
                onChatPresentationChanged: { isPresented in
                    DispatchQueue.main.async {
                        guard isChatPresented != isPresented else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isChatPresented = isPresented
                        }
                    }
                }
            )
        }
    }
}

#Preview {
    MainView()
}
