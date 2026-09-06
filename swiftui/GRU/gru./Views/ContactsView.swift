import SwiftUI
import UIKit

@MainActor
struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @Bindable private var service = ChatService.shared

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @State private var showingNewChat = false
    @State private var gruSearchResults: [UserSearchDTO] = []
    @State private var isSearchingGRU = false
    @State private var creatingUserID: String?
    @State private var selectedChat: Chat?
    @State private var showSelectedChat = false

    @FocusState private var searchFocused: Bool
    @Environment(\.openURL) private var openURL

    private var currentTheme: GRUAppTheme {
        let selected = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(selected) ? selected : .blackMoonCat
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        GRUAgentCard()
                        searchField

                        if isSearchingGRU {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(currentTheme.accent)

                                Text(GRUL10n.text("Ищем людей в gru.…"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        if !gruSearchResults.isEmpty {
                            sectionHeader(
                                "Найдено в gru.",
                                subtitle: "можно сразу открыть чат",
                                icon: "sparkles"
                            )
                            gruSearchSection
                        }

                        if !filteredGRUContacts.isEmpty {
                            sectionHeader(
                                "Мои контакты gru.",
                                subtitle: "люди из твоих переписок",
                                icon: "bolt.horizontal.circle.fill"
                            )
                            gruContactsSection
                        }

                        sectionHeader(
                            "Телефонная книга",
                            subtitle: "контакты iPhone и приглашения",
                            icon: "person.crop.circle.badge.plus"
                        )
                        phoneBookSection

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(GRUL10n.text("Люди"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GRUNeonIconButton(
                        systemName: "envelope.badge.fill",
                        accessibilityLabel: GRUL10n.text("Новый чат"),
                        size: 38,
                        iconSize: 15
                    ) {
                        showingNewChat = true
                    }
                }
            }
            .navigationDestination(isPresented: $showSelectedChat) {
                if let selectedChat {
                    ChatView(chat: selectedChat)
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
            GRUNeonIcon(
                systemName: searchFocused
                    ? "sparkle.magnifyingglass"
                    : "magnifyingglass",
                size: 36,
                iconSize: 14
            )

            TextField(
                GRUL10n.text("Имя, никнейм или номер"),
                text: $vm.searchText
            )
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .submitLabel(.search)

            if !vm.searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        vm.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GRUL10n.text("Очистить поиск"))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 21, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(
                    currentTheme.accent.opacity(searchFocused ? 0.52 : 0.12),
                    lineWidth: searchFocused ? 1.4 : 1
                )
        }
        .shadow(
            color: searchFocused
                ? currentTheme.accent.opacity(0.20)
                : .clear,
            radius: 13
        )
        .animation(.easeOut(duration: 0.18), value: searchFocused)
    }

    func sectionHeader(
        _ title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            GRUNeonIcon(systemName: icon, size: 34, iconSize: 13)

            VStack(alignment: .leading, spacing: 2) {
                Text(GRUL10n.text(title))
                    .font(.headline)

                Text(GRUL10n.text(subtitle))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    var gruContactsSection: some View {
        VStack(spacing: 10) {
            ForEach(filteredGRUContacts) { user in
                Button {
                    createChat(with: user)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(user: user, size: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.body.weight(.bold))
                                .foregroundStyle(GRUColors.text)
                                .lineLimit(1)

                            if !user.username.isEmpty {
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        presencePill(user.isOnline)

                        GRUNeonIcon(
                            systemName: "envelope.fill",
                            size: 38,
                            iconSize: 14
                        )
                    }
                    .padding(12)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .stroke(
                            user.isOnline
                                ? currentTheme.accent.opacity(0.16)
                                : Color.white.opacity(0.045),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    GRUL10n.format(
                        "Открыть чат с %@",
                        user.displayName
                    )
                )
            }
        }
    }

    func presencePill(_ online: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(
                    online
                        ? currentTheme.accent
                        : Color.secondary.opacity(0.55)
                )
                .frame(width: 6, height: 6)
                .shadow(
                    color: online
                        ? currentTheme.accent.opacity(0.8)
                        : .clear,
                    radius: 5
                )

            Text(GRUL10n.text(online ? "online" : "offline"))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(online ? currentTheme.accent : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            online
                ? currentTheme.accent.opacity(0.09)
                : Color.white.opacity(0.035),
            in: Capsule()
        )
    }

    var gruSearchSection: some View {
        VStack(spacing: 10) {
            ForEach(gruSearchResults) { user in
                Button {
                    createServerChat(with: user)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            currentTheme.accent.opacity(0.52),
                                            currentTheme.card,
                                            currentTheme.secondaryAccent.opacity(0.42)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(String(user.nickname.prefix(1)).uppercased())
                                .font(
                                    .system(
                                        size: 17,
                                        weight: .black,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(.white)
                        }
                        .frame(width: 50, height: 50)
                        .overlay {
                            Circle()
                                .stroke(GRUColors.neonGradient, lineWidth: 1.2)
                        }
                        .shadow(
                            color: currentTheme.accent.opacity(0.22),
                            radius: 9
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.nickname)
                                .font(.body.weight(.bold))
                                .foregroundStyle(GRUColors.text)
                                .lineLimit(1)

                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 9, weight: .bold))

                                Text(GRUL10n.text("в gru."))
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(currentTheme.accent)
                        }

                        Spacer()

                        if creatingUserID == user.id {
                            ProgressView()
                                .tint(currentTheme.accent)
                                .frame(width: 40, height: 40)
                        } else {
                            GRUNeonIcon(
                                systemName: "envelope.fill",
                                size: 40,
                                iconSize: 15
                            )
                        }
                    }
                    .padding(12)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .stroke(currentTheme.accent.opacity(0.13), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(creatingUserID != nil)
                .accessibilityLabel(
                    GRUL10n.format(
                        "Начать чат с %@",
                        user.nickname
                    )
                )
            }
        }
    }

    @ViewBuilder
    var phoneBookSection: some View {
        switch vm.accessState {
        case .unknown, .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(currentTheme.accent)

                Text(GRUL10n.text("Загружаем контакты iPhone…"))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )

        case .denied:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    GRUNeonIcon(
                        systemName: "person.crop.circle.badge.exclamationmark",
                        size: 38,
                        iconSize: 15
                    )

                    Text(GRUL10n.text("Доступ к контактам выключен"))
                        .font(.headline)
                }

                Text(
                    GRUL10n.text(
                        "Разреши gru. доступ к телефонной книге — тогда здесь появятся контакты и приглашение через Messages."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button(GRUL10n.text("Открыть Настройки")) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(currentTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(currentTheme.accent.opacity(0.14), lineWidth: 1)
            }

        case .granted:
            if vm.filteredPhoneContacts.isEmpty {
                Text(
                    GRUL10n.text(
                        vm.searchText.isEmpty
                            ? "В телефонной книге нет контактов с номером."
                            : "Ничего не найдено."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.filteredPhoneContacts) { contact in
                        phoneContactRow(contact)
                    }
                }
            }
        }
    }

    var allGRUContacts: [User] {
        var seen = Set<String>()
        let currentID = service.currentUser.id

        return service.chats
            .flatMap(\.users)
            .filter { $0.id != currentID }
            .filter { user in
                let key = user.serverID ?? user.id.uuidString
                return seen.insert(key).inserted
            }
    }

    var filteredGRUContacts: [User] {
        let query = vm.normalizedSearch
        guard !query.isEmpty else { return allGRUContacts }

        return allGRUContacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    func phoneContactRow(_ contact: PhoneContact) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(currentTheme.accent.opacity(0.10))

                Text(contact.initials.isEmpty ? "?" : contact.initials)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(currentTheme.accent)
            }
            .frame(width: 46, height: 46)
            .overlay {
                Circle()
                    .stroke(currentTheme.accent.opacity(0.22), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text(contact.primaryPhone ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                invite(contact)
            } label: {
                GRUNeonIcon(
                    systemName: "message.fill",
                    size: 40,
                    iconSize: 15
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GRUL10n.text("Пригласить через Messages"))
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
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
                let chat = try await service.createServerChat(with: user)
                selectedChat = chat
                showSelectedChat = true
                searchFocused = false

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
        guard let serverID = user.serverID,
              !serverID.isEmpty else {
            service.createChat(username: user.displayName)
            return
        }

        createServerChat(
            with: UserSearchDTO(
                id: serverID,
                nickname: user.displayName
            )
        )
    }
}

#Preview { ContactsView() }
