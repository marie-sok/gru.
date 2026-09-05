import SwiftUI

struct MainView: View {
    @State private var selectedTab: AppTab = .chats
    @State private var isChatPresented = false
    @State private var isAgentPresented = false
    @State private var showBotTestLab = false

    var body: some View {
        ZStack {
            GRUAppBackdrop()
            selectedContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isChatPresented && !isAgentPresented {
                GRUTabBar(selectedTab: $selectedTab)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            GRUReleaseSettingsView()
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
