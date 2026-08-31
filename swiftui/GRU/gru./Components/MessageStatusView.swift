//
//  MessageStatusView.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import SwiftUI

struct MessageStatusView: View {

    let status: MessageStatus

    var body: some View {

        switch status {

        case .sending:

            Image(systemName: "clock")

        case .sent:

            Image(systemName: "checkmark")

        case .delivered:

            Image(systemName: "checkmark.circle")

        case .read:

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.blue)

        case .failed:

            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {

    VStack {

        ForEach(
            MessageStatus.allCases,
            id: \.self
        ) {

            MessageStatusView(
                status: $0
            )
        }
    }
}