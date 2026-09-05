import SwiftUI

struct MainView: View {
    @State private var selectedTab: AppTab = .chats
    @State private var isChatPresented = false

    var body: some View {
        ZStack {
            GRUAppBackdrop()
            selectedContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isChatPresented {
                GRUTabBar(selectedTab: $selectedTab)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: selectedTab) { _, _ in
            if isChatPresented {
                isChatPresented = false
            }
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
}

#Preview {
    MainView()
}
