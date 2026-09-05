import SwiftUI
import UIKit

@MainActor
struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @Bindable private var service = ChatService.shared

    @State private var showingNewChat = false
    @State private var gruSearchResults: [UserSearchDTO] = []
    @State private var isSearchingGRU = false
    @State private var creatingUserID: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        GRUAgentCard()
                        searchField

                        if isSearchingGRU {
                            ProgressView("Ищем в gru.…")
                                .tint(GRUColors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !gruSearchResults.isEmpty {
                            sectionHeader("Найдено в gru.", icon: "sparkles")
                            gruSearchSection
                        }

                        if !filteredGRUContacts.isEmpty {
                            sectionHeader("Мои контакты gru.", icon: "bolt.horizontal.circle.fill")
                            gruContactsSection
                        }

                        sectionHeader("Телефонная книга", icon: "person.crop.circle.badge.plus")
                        phoneBookSection

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Люди")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GRUNeonIconButton(
                        systemName: "envelope.badge.fill",
                        accessibilityLabel: "Новый чат",
                        size: 38,
                        iconSize: 15
                    ) {
                        showingNewChat = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView()
        }
        .task {
            await service.loadChats()
            await vm.loadPhoneContacts()
        }
        .task(id: vm.searchText) {
            await searchGRUUsers()
        }
    }
}

private extension ContactsView {
    var searchField: some View {
        HStack(spacing: 10) {
            GRUNeonIcon(systemName: "magnifyingglass", size: 34, iconSize: 14)

            TextField("Имя или номер", text: $vm.searchText)
                .textFieldStyle(.plain)

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    GRUNeonIcon(systemName: "xmark", size: 30, iconSize: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(GRUColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GRUColors.accent.opacity(0.08), lineWidth: 1)
        }
    }

    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            GRUNeonIcon(systemName: icon, size: 32, iconSize: 13)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    var gruContactsSection: some View {
        VStack(spacing: 10) {
            ForEach(filteredGRUContacts) { user in
                HStack(spacing: 12) {
                    userAvatar(user)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.displayName)
                            .font(.body.weight(.semibold))
                        Text("@\(user.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(user.isOnline ? GRUColors.accent : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .shadow(
                            color: user.isOnline ? GRUColors.accent.opacity(0.70) : .clear,
                            radius: 5
                        )

                    Button {
                        createChat(with: user)
                    } label: {
                        GRUNeonIcon(systemName: "envelope.fill", size: 36, iconSize: 14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(GRUColors.card.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    var gruSearchSection: some View {
        VStack(spacing: 10) {
            ForEach(gruSearchResults) { user in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(GRUColors.accent.opacity(0.12))
                        Text(String(user.nickname.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(GRUColors.accent)
                    }
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle().stroke(GRUColors.neonGradient, lineWidth: 1)
                    }
                    .shadow(color: GRUColors.accent.opacity(0.22), radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.nickname)
                            .font(.body.weight(.semibold))
                        Text("Пользователь gru.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        createServerChat(with: user)
                    } label: {
                        if creatingUserID == user.id {
                            ProgressView()
                                .tint(GRUColors.accent)
                                .frame(width: 38, height: 38)
                        } else {
                            GRUNeonIcon(
                                systemName: "envelope.fill",
                                size: 38,
                                iconSize: 15
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(creatingUserID != nil)
                }
                .padding(12)
                .background(GRUColors.card.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    var phoneBookSection: some View {
        switch vm.accessState {
        case .unknown, .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(GRUColors.accent)
                Text("Загружаем контакты iPhone…")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
            .background(GRUColors.card.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        case .denied:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    GRUNeonIcon(systemName: "person.crop.circle.badge.exclamationmark", size: 38, iconSize: 15)
                    Text("Доступ к контактам выключен")
                        .font(.headline)
                }

                Text("Разреши gru. доступ к телефонной книге — тогда здесь появятся контакты и приглашение через Messages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Открыть Настройки") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(GRUColors.card.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        case .granted:
            if vm.filteredPhoneContacts.isEmpty {
                Text(vm.searchText.isEmpty ? "В телефонной книге нет контактов с номером." : "Ничего не найдено.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(GRUColors.card.opacity(0.76))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.filteredPhoneContacts) { contact in
                        phoneContactRow(contact)
                    }
                }
            }
        }
    }

    var filteredGRUContacts: [User] {
        var seen = Set<String>()
        let currentID = service.currentUser.id

        let all = service.chats
            .flatMap(\.users)
            .filter { $0.id != currentID }
            .filter { user in
                let key = user.serverID ?? user.id.uuidString
                return seen.insert(key).inserted
            }

        let query = vm.normalizedSearch
        guard !query.isEmpty else { return all }

        return all.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    func phoneContactRow(_ contact: PhoneContact) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.10))
                Text(contact.initials.isEmpty ? "?" : contact.initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(GRUColors.accent)
            }
            .frame(width: 42, height: 42)
            .overlay {
                Circle().stroke(GRUColors.accent.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: GRUColors.accent.opacity(0.12), radius: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.body.weight(.semibold))
                Text(contact.primaryPhone ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                invite(contact)
            } label: {
                GRUNeonIcon(systemName: "message.fill", size: 38, iconSize: 15)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Пригласить через Messages")
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func userAvatar(_ user: User) -> some View {
        ZStack {
            Circle().fill(GRUColors.accent.opacity(0.10))
            Text(String(user.displayName.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(GRUColors.accent)
        }
        .frame(width: 42, height: 42)
        .overlay {
            Circle().stroke(GRUColors.accent.opacity(0.20), lineWidth: 1)
        }
    }

    func invite(_ contact: PhoneContact) {
        guard let phone = contact.primaryPhone else { return }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "sms:\(digits)") else { return }
        openURL(url)
    }

    func searchGRUUsers() async {
        let query = vm.normalizedSearch

        guard query.count >= 2 else {
            gruSearchResults = []
            isSearchingGRU = false
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(320))
        } catch {
            return
        }

        guard !Task.isCancelled,
              let token = TokenStorage.shared.token,
              !token.isEmpty
        else {
            return
        }

        isSearchingGRU = true
        defer { isSearchingGRU = false }

        do {
            let users = try await UserAPIService.shared.searchUsers(
                nickname: query,
                token: token
            )

            guard !Task.isCancelled else { return }

            gruSearchResults = users.filter {
                $0.id != service.currentUser.serverID
            }
        } catch is CancellationError {
            return
        } catch {
            gruSearchResults = []
            print("❌ gru. contacts search error:", error)
        }
    }

    func createServerChat(with user: UserSearchDTO) {
        guard creatingUserID == nil else { return }
        creatingUserID = user.id

        Task {
            defer { creatingUserID = nil }

            do {
                _ = try await service.createServerChat(with: user)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            } catch {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.error)
                print("❌ Create gru. contact chat error:", error)
            }
        }
    }

    func createChat(with user: User) {
        guard let serverID = user.serverID, !serverID.isEmpty else {
            service.createChat(username: user.displayName)
            return
        }

        createServerChat(
            with: UserSearchDTO(id: serverID, nickname: user.displayName)
        )
    }
}

#Preview { ContactsView() }
