import Foundation

enum GRUAppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    static let storageKey = "gru.settings.language.v1"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .russian: return Locale(identifier: "ru_RU")
        case .english: return Locale(identifier: "en_US")
        }
    }

    var badge: String {
        switch self {
        case .russian: return "RU"
        case .english: return "EN"
        }
    }

    var nativeTitle: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    static var defaultLanguage: GRUAppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("en") ? .english : .russian
    }

    static var selected: GRUAppLanguage {
        guard
            let raw = UserDefaults.standard.string(forKey: storageKey),
            let value = GRUAppLanguage(rawValue: raw)
        else { return defaultLanguage }
        return value
    }
}

enum GRUL10n {
    static var language: GRUAppLanguage { GRUAppLanguage.selected }

    static func text(_ key: String) -> String {
        let localized: String

        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localized = bundle.localizedString(forKey: key, value: key, table: nil)
        } else {
            localized = key
        }

        guard localized == key else { return localized }
        return fallback[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: language.locale, arguments: arguments)
    }

    private static var fallback: [String: String] {
        switch language {
        case .russian:
            return [
                "Online": "online",
                "Offline": "offline",
                "Chat": "Чат",
                "Username": "Username",
                "Recovery code": "Код восстановления",
                "SAFETY NUMBER": "КОД БЕЗОПАСНОСТИ",
                "Fingerprint identity": "Отпечаток ключа",
                "SIGNAL CARD": "КАРТОЧКА СВЯЗИ",
                "BLOCKED": "ЗАБЛОКИРОВАН",
                "READY": "ГОТОВО",
                "ACTIVE": "АКТИВНО"
            ]

        case .english:
            return [
                "Файл": "File",
                "Найти контакт": "Find contact",
                "Отправить контакт": "Send contact",
                "Видеосообщение": "Video message",
                "Аудио": "Audio",
                "Редактирование": "Editing",
                "Аватар": "Avatar",
                "Удалить аватар": "Remove avatar",
                "Изменить аватар": "Change avatar",
                "Никнейм": "Nickname",
                "Статус": "Status",
                "Био": "Bio",
                "Голосовые и видео-сообщения остаются только внутри переписок и не создают отдельную медиатеку.": "Voice and video messages stay inside chats and do not create a separate media library.",
                "Сообщение": "Message",
                "Отпусти — отменим": "Release to cancel",
                "Запись зафиксирована": "Recording locked",
                "Отпусти для отправки": "Release to send",
                "Отправить": "Send",
                "Отправить голосовое": "Send voice message",
                "двойной тап — режим": "double tap — mode",
                "удержание — запись": "hold — record",
                "Двойной тап переключает режим записи. Удерживай для записи. Свайп влево отменяет, вверх фиксирует.": "Double tap switches recording mode. Hold to record. Swipe left to cancel, up to lock.",
                "Закрыть вложения": "Close attachments",
                "Добавить вложение": "Add attachment",
                "голосовое": "voice",
                "видео": "video",
                "Действия с сообщением": "Message actions",
                "изм.": "edited",
                "Удалить сообщение?": "Delete message?",
                "Удалить только у себя": "Delete for me",
                "Удалить у себя и собеседника": "Delete for both",
                "Сообщение исчезнет у обоих участников чата.": "The message will disappear for both chat participants.",
                "Сообщение исчезнет только на этом устройстве.": "The message will disappear only on this device.",
                "Ответить": "Reply",
                "Реакция": "Reaction",
                "Снять выбор": "Deselect",
                "Повторить отправку": "Retry sending",
                "очередь": "queued",
                "Сообщение в очереди на отправку": "Message queued for sending",
                "Сообщение отправляется": "Message is sending",
                "Не удалось отправить сообщение": "Message failed to send",
                "Online": "online",
                "Offline": "offline",
                "Chat": "Chat",
                "Сообщения можно повторить после восстановления связи": "Messages can be retried after the connection is restored",
                "Отправь обычное видео из медиатеки или сними новое.": "Send a video from your library or record a new one.",
                "Отменить выбор": "Cancel selection",
                "Удалить выбранные": "Delete selected",
                "Открыть профиль пользователя": "Open user profile",
                "Удалить у себя (%d)": "Delete for me (%d)",
                "Удалить у всех (%d)": "Delete for everyone (%d)",
                "Выбранные сообщения исчезнут без служебных заглушек.": "Selected messages will disappear without placeholder messages.",
                "У всех можно удалить только сообщения, отправленные тобой. Для смешанного выбора доступно удаление у себя.": "You can delete for everyone only messages you sent. For mixed selections, delete for me is available.",
                "История и вложения этого чата будут удалены с сервера. Действие нельзя отменить.": "This chat history and attachments will be deleted from the server. This cannot be undone.",
                "Не удалось удалить чат: серверный идентификатор или сессия недоступны.": "Could not delete chat: server identifier or session is unavailable.",
                "Не удалось удалить чат: %@": "Could not delete chat: %@",
                "сообщений": "messages",
                "медиа": "media",
                "звук": "sound",
                "Поиск в переписке": "Search conversation",
                "Общие медиа": "Shared media",
                "Оформление переписки": "Chat appearance",
                "Профиль связан с реальным участником переписки. Поиск, медиа, оформление, жалоба и блокировка находятся в одном месте.": "This profile belongs to the real chat participant. Search, media, appearance, reporting and blocking are available here.",
                "Пожаловаться": "Report",
                "Спам": "Spam",
                "Оскорбления или травля": "Harassment or bullying",
                "Опасный или незаконный контент": "Dangerous or illegal content",
                "Другое": "Other",
                "Жалоба сохраняется на backend GRU для последующей модерации.": "The report is saved to the GRU backend for moderation.",
                "Заблокировать пользователя?": "Block user?",
                "Заблокировать": "Block",
                "После блокировки новые сообщения между вами будут отклоняться backend.": "After blocking, new messages between you will be rejected by the backend.",
                "Безопасность": "Security",
                "Разблокировать": "Unblock",
                "Пользователь заблокирован. Backend не позволит отправлять новые сообщения между вами.": "User blocked. The backend will reject new messages between you.",
                "Пользователь разблокирован.": "User unblocked.",
                "Жалоба отправлена.": "Report sent.",
                "Медиа пока нет": "No media yet",
                "Фото, видео, голосовые и файлы из переписки появятся здесь.": "Photos, videos, voice messages and files from this chat will appear here.",
                "Вложение": "Attachment",
                "Голосовое": "Voice message",
                "Восстановление E2EE": "E2EE Recovery",
                "Смена iPhone, переустановка и recovery code": "New iPhone, reinstall and recovery code",
                "Моя защита": "My Security",
                "Приватные X25519/Ed25519 ключи не хранятся на backend. Сервер получает только зашифрованный recovery backup.": "Private X25519/Ed25519 keys are not stored on the backend. The server receives only an encrypted recovery backup.",
                "Проверка контактов": "Contact Verification",
                "Создай личный чат — здесь появится проверка E2EE-ключей.": "Create a direct chat to verify E2EE keys here.",
                "Проверить защищённый ключ": "Verify secure key",
                "Защита gru.": "gru. Security",
                "Проверяем ключи…": "Checking keys…",
                "Проверка E2EE": "E2EE Verification",
                "Личность ключа подтверждена": "Key identity verified",
                "Ключ изменился — требуется проверка": "Key changed — verification required",
                "E2EE включено, ключ ещё не сверен вручную": "E2EE is enabled; the key has not been manually verified yet",
                "SAFETY NUMBER": "SAFETY NUMBER",
                "Скопировано": "Copied",
                "Скопировать код": "Copy code",
                "Сканируйте QR друг у друга или сравните safety number по другому каналу — например лично или по звонку.": "Scan each other's QR codes or compare the safety number through another channel, such as in person or by phone.",
                "Fingerprint identity": "Identity fingerprint",
                "Ключ подтверждён": "Key verified",
                "Коды совпадают — подтвердить": "Codes match — verify",
                "Подтверждай только после реального сравнения. Эта кнопка может принять новый ключ после его смены, поэтому не нажимай её вслепую.": "Verify only after a real comparison. This button can accept a new key after it changes, so do not use it without checking.",
                "Сессия или ID собеседника недоступны.": "Session or peer ID is unavailable.",
                "Состояние": "Status",
                "Локальная E2EE-личность": "Local E2EE identity",
                "Ключ восстановления в iCloud Keychain": "Recovery key in iCloud Keychain",
                "Создать / обновить резервную копию": "Create / update backup",
                "Показать recovery code": "Show recovery code",
                "Восстановление": "Recovery",
                "Backend хранит только зашифрованный backup. Recovery key и приватные X25519/Ed25519 ключи серверу не передаются.": "The backend stores only an encrypted backup. The recovery key and private X25519/Ed25519 keys are never sent to the server.",
                "Recovery code": "Recovery code",
                "Скопировать": "Copy",
                "Обновляем защиту…": "Updating security…",
                "Сессия недоступна.": "Session unavailable.",
                "Test lab использует тот же сценарий видео, что и обычный чат.": "Test lab uses the same video flow as a regular chat.",
                "полный локальный полигон чата": "full local chat playground",
                "Следующая тема": "Next theme",
                "Сбросить test lab": "Reset test lab",
                "Проверяй здесь обычный текст, reply, edit, delete, reactions, multi-select, фото, видео, документы, контакты, голосовые и кото-кружки. Ничего из этого test lab не отправляет в реальные чаты.": "Test regular text, reply, edit, delete, reactions, multi-select, photos, videos, documents, contacts, voice messages and cat circles here. Nothing in test lab is sent to real chats.",
                "Я локальный собеседник test lab. Свайпни это сообщение влево для reply или зажми для реакций и действий.": "I am the local test lab peer. Swipe this message left to reply, or press and hold for reactions and actions.",
                "Это моё тестовое сообщение — его можно редактировать, копировать, выбрать и удалить.": "This is my test message — you can edit, copy, select and delete it."
            ]
        }
    }
}
