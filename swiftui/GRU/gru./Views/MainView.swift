import SwiftUI
import UIKit

@MainActor
struct MainView: View {
    @State private var selectedTab: AppTab = .chats
    @State private var isChatPresented = false
    @State private var isAgentPresented = false
    @State private var showBotTestLab = false
    @State private var showConnectivityDiagnostics = false
    @StateObject private var connectivity = GRUConnectivityCenter.shared

    var body: some View {
        ZStack {
            // One persistent animated backdrop for all tabs.
            // Individual tabs must not create another animated wallpaper.
            GRUAppBackdrop()

            selectedContent
                .transaction { transaction in
                    transaction.animation = nil
                }
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
            }
        }
        .onAppear {
            dismissAnyKeyboard()
            connectivity.start()
        }
        .sheet(isPresented: $showBotTestLab) {
            NavigationStack {
                GRUBetaTestChatView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(GRUL10n.text("Готово")) {
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
                            Button(GRUL10n.text("Готово")) {
                                showConnectivityDiagnostics = false
                            }
                        }
                    }
            }
        }
        .onChange(of: selectedTab) { _, _ in
            dismissAnyKeyboard()
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
            selectedTab = .chats
            isChatPresented = false
            isAgentPresented = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenContacts)) { _ in
            selectedTab = .contacts
            isChatPresented = false
            isAgentPresented = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .gruBotOpenSettings)) { _ in
            selectedTab = .settings
            isChatPresented = false
            isAgentPresented = false
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
            BetaSettingsView()
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

    private func dismissAnyKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

#Preview {
    MainView()
}
