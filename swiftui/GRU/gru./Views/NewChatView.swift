
import SwiftUI

@MainActor
struct NewChatView: View {

    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

    // MARK: - Service

    @Bindable
    private var service = ChatService.shared

    // MARK: - Search

    @State
    private var searchText = ""

    @State
    private var results: [UserSearchDTO] = []

    @State
    private var isSearching = false

    // MARK: - Create Chat

    @State
    private var creatingUserID: String?

    // MARK: - Error

    @State
    private var errorMessage: String?

    // MARK: - Focus

    @FocusState
    private var searchIsFocused: Bool

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ZStack {

                GRUAppBackdrop()

                VStack(spacing: 0) {

                    searchField

                    content
                }
            }
            .navigationTitle("Новый чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .topBarLeading
                ) {

                    Button("Отмена") {

                        dismiss()
                    }
                }
            }
        }
        .task(id: searchText) {

            await searchUsers()
        }
        .onAppear {

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.25
            ) {

                searchIsFocused = true
            }
        }
    }
}

// MARK: - Search Field

private extension NewChatView {

    var searchField: some View {

        HStack(spacing: 11) {

            Image(
                systemName: "magnifyingglass"
            )
            .font(
                .system(
                    size: 16,
                    weight: .medium
                )
            )
            .foregroundStyle(.secondary)

            TextField(
                "Найти по nickname",
                text: $searchText
            )
            .focused($searchIsFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(.none)
            .keyboardType(.default)
            .submitLabel(.search)

            if isSearching {

                ProgressView()
                    .controlSize(.small)

            } else if !searchText.isEmpty {

                Button {

                    searchText = ""
                    results = []
                    errorMessage = nil

                } label: {

                    Image(
                        systemName: "xmark.circle.fill"
                    )
                    .font(
                        .system(
                            size: 17
                        )
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(
            .horizontal,
            16
        )
        .frame(
            minHeight: 50
        )
        .background(
            GRUColors.card
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .top,
            14
        )
        .padding(
            .bottom,
            8
        )
    }
}

// MARK: - Content

private extension NewChatView {

    @ViewBuilder
    var content: some View {

        let query =
            searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        if query.isEmpty {

            startView

        } else if query.count < 2 {

            hintView

        } else if let errorMessage {

            errorView(
                errorMessage
            )

        } else if isSearching &&
                    results.isEmpty {

            searchingView

        } else if results.isEmpty {

            noResultsView

        } else {

            resultsList
        }
    }
}

// MARK: - Start

private extension NewChatView {

    var startView: some View {

        VStack(spacing: 14) {

            Spacer()

            ZStack {

                Circle()
                    .fill(
                        GRUColors.card
                    )
                    .frame(
                        width: 74,
                        height: 74
                    )

                GRUEnvelope()
                    .stroke(
                        GRUColors.accent,
                        style: StrokeStyle(
                            lineWidth: 1.7,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(
                        width: 32,
                        height: 23
                    )
            }

            Text(
                "Найди человека"
            )
            .font(
                .system(
                    size: 20,
                    weight: .semibold,
                    design: .rounded
                )
            )

            Text(
                "Начни вводить nickname"
            )
            .font(
                .system(
                    size: 14,
                    weight: .regular,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(
            .bottom,
            70
        )
    }
}

// MARK: - Hint

private extension NewChatView {

    var hintView: some View {

        VStack(spacing: 8) {

            Text(
                "Продолжай ввод"
            )
            .font(
                .system(
                    size: 16,
                    weight: .medium,
                    design: .rounded
                )
            )

            Text(
                "Нужно минимум 2 символа"
            )
            .font(
                .system(
                    size: 13,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .top,
            42
        )
    }
}

// MARK: - Searching

private extension NewChatView {

    var searchingView: some View {

        VStack(spacing: 12) {

            ProgressView()

            Text(
                "Ищем…"
            )
            .font(
                .system(
                    size: 14,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .top,
            42
        )
    }
}

// MARK: - No Results

private extension NewChatView {

    var noResultsView: some View {

        VStack(spacing: 10) {

            Image(
                systemName: "person.crop.circle.badge.questionmark"
            )
            .font(
                .system(
                    size: 30,
                    weight: .light
                )
            )
            .foregroundStyle(.secondary)

            Text(
                "Никого не нашли"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold,
                    design: .rounded
                )
            )

            Text(
                "Проверь nickname"
            )
            .font(
                .system(
                    size: 13,
                    design: .rounded
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .top,
            42
        )
    }
}

// MARK: - Error

private extension NewChatView {

    func errorView(
        _ message: String
    ) -> some View {

        VStack(spacing: 12) {

            Image(
                systemName: "exclamationmark.circle"
            )
            .font(
                .system(
                    size: 29,
                    weight: .light
                )
            )
            .foregroundStyle(.secondary)

            Text(
                "Не удалось выполнить поиск"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold,
                    design: .rounded
                )
            )

            Text(message)
                .font(
                    .system(
                        size: 13,
                        design: .rounded
                    )
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(
                "Повторить"
            ) {

                Task {

                    await searchUsers(
                        skipDelay: true
                    )
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(
            .horizontal,
            30
        )
        .padding(
            .top,
            42
        )
        .frame(
            maxWidth: .infinity
        )
    }
}

// MARK: - Results

private extension NewChatView {

    var resultsList: some View {

        ScrollView {

            LazyVStack(
                spacing: 0
            ) {

                ForEach(results) { user in

                    userRow(user)

                    Divider()
                        .padding(
                            .leading,
                            78
                        )
                }
            }
            .padding(
                .horizontal,
                18
            )
            .padding(
                .top,
                4
            )
        }
        .scrollDismissesKeyboard(
            .interactively
        )
    }
}

// MARK: - User Row

private extension NewChatView {

    func userRow(
        _ user: UserSearchDTO
    ) -> some View {

        Button {

            Task {

                await createChat(
                    with: user
                )
            }

        } label: {

            HStack(spacing: 13) {

                avatar(
                    for: user
                )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        user.nickname
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)

                    Text(
                        "@\(user.nickname)"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .regular,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if creatingUserID ==
                    user.id {

                    ProgressView()
                        .controlSize(.small)

                } else {

                    Image(
                        systemName: "envelope"
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(
                        GRUColors.accent
                    )
                }
            }
            .padding(
                .vertical,
                11
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
        .disabled(
            creatingUserID != nil
        )
    }
}

// MARK: - Avatar

private extension NewChatView {

    func avatar(
        for user: UserSearchDTO
    ) -> some View {

        ZStack {

            Circle()
                .fill(
                    GRUColors.card
                )

            Text(
                initial(
                    for: user.nickname
                )
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(
                GRUColors.accent
            )
        }
        .frame(
            width: 48,
            height: 48
        )
    }
}

// MARK: - Search

private extension NewChatView {

    func searchUsers(
        skipDelay: Bool = false
    ) async {

        let query =
            searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard query.count >= 2
        else {

            results = []
            errorMessage = nil
            isSearching = false

            return
        }

        if !skipDelay {

            do {

                try await Task.sleep(
                    for: .milliseconds(350)
                )

            } catch {

                return
            }
        }

        guard !Task.isCancelled
        else {

            return
        }

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {

            results = []

            errorMessage =
                "Сессия не найдена"

            return
        }

        isSearching = true
        errorMessage = nil

        defer {

            isSearching = false
        }

        do {

            let found =
                try await UserAPIService.shared
                    .searchUsers(
                        nickname: query,
                        token: token
                    )

            guard !Task.isCancelled
            else {

                return
            }

            results = found

        } catch is CancellationError {

            return

        } catch {

            results = []

            errorMessage =
                error.localizedDescription

            print(
                "❌ User search error:",
                error
            )
        }
    }
}

// MARK: - Create Chat

private extension NewChatView {

    func createChat(
        with user: UserSearchDTO
    ) async {

        guard creatingUserID == nil
        else {

            return
        }

        creatingUserID =
            user.id

        errorMessage = nil

        defer {

            creatingUserID = nil
        }

        do {

            _ =
                try await service
                    .createServerChat(
                        with: user
                    )

            searchIsFocused = false

            dismiss()

        } catch {

            errorMessage =
                error.localizedDescription

            print(
                "❌ Create chat error:",
                error
            )
        }
    }
}

// MARK: - Helpers

private extension NewChatView {

    func initial(
        for nickname: String
    ) -> String {

        let clean =
            nickname
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard let first =
                clean.first
        else {

            return "?"
        }

        return String(first)
            .uppercased()
    }
}

// MARK: - Preview

#Preview {

    NewChatView()
}
