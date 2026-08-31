import SwiftUI

enum GRUColors {
    static var accent: Color { GRUAppTheme.current.accent }
    static var accentSecondary: Color { GRUAppTheme.current.secondaryAccent }
    static var background: Color { GRUAppTheme.current.background }
    static var card: Color { GRUAppTheme.current.card }
    static var input: Color { GRUAppTheme.current.card.opacity(0.94) }
    static var text: Color { Color.white.opacity(0.96) }
    static var secondary: Color { Color.white.opacity(0.58) }
    static var separator: Color { Color.white.opacity(0.075) }
    static var incomingBubble: Color { GRUAppTheme.current.card.opacity(0.96) }
    static var outgoingBubble: Color { GRUAppTheme.current.accent.opacity(0.19) }

    static var neonGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent,
                Color.white.opacity(0.88),
                accentSecondary,
                accent
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Pastel {
        static let milkBackground = Color(red: 0.98, green: 0.96, blue: 0.92)
        static let milkCard = Color(red: 1.00, green: 0.99, blue: 0.97)
        static let milkAccent = Color(red: 0.53, green: 0.45, blue: 0.39)
        static let blushBackground = Color(red: 0.98, green: 0.91, blue: 0.92)
        static let blushCard = Color(red: 1.00, green: 0.96, blue: 0.97)
        static let blushAccent = Color(red: 0.64, green: 0.39, blue: 0.45)
        static let lavenderBackground = Color(red: 0.94, green: 0.92, blue: 0.98)
        static let lavenderCard = Color(red: 0.98, green: 0.97, blue: 1.00)
        static let lavenderAccent = Color(red: 0.47, green: 0.40, blue: 0.64)
        static let sageBackground = Color(red: 0.91, green: 0.95, blue: 0.90)
        static let sageCard = Color(red: 0.96, green: 0.98, blue: 0.95)
        static let sageAccent = Color(red: 0.36, green: 0.49, blue: 0.37)
        static let skyBackground = Color(red: 0.91, green: 0.95, blue: 0.98)
        static let skyCard = Color(red: 0.97, green: 0.99, blue: 1.00)
        static let skyAccent = Color(red: 0.34, green: 0.49, blue: 0.62)
        static let peachBackground = Color(red: 0.99, green: 0.93, blue: 0.88)
        static let peachCard = Color(red: 1.00, green: 0.97, blue: 0.94)
        static let peachAccent = Color(red: 0.67, green: 0.42, blue: 0.31)
    }
}
