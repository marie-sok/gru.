import SwiftUI

/// Emergency switch for the experimental still-screenshot compositor.
/// Keep this scoped to ChatView; RootView/auth must never depend on it.
enum GRUPrivacyFeatures {
    static let chatScreenshotShieldEnabled = true
}

/// Static capture replacement artwork. It is bundled in Assets.xcassets so it
/// is ready synchronously before the user presses the hardware screenshot keys.
struct GRUPrivacyCaptureArtwork: View {
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                Image("GRUPrivacyCapture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss?()
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("gru. privacy")
    }
}
