//
//  UnreadBadge.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import SwiftUI

struct UnreadBadge: View {

    let count: Int

    var body: some View {

        if count > 0 {

            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GRUColors.accent)
                .clipShape(Capsule())
        }
    }
}

#Preview {

    VStack {

        UnreadBadge(count: 1)

        UnreadBadge(count: 25)

        UnreadBadge(count: 128)
    }
}