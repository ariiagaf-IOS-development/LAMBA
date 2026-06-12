//
//  AppCard.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.largeRadius))
            .shadow(
                color: AppTheme.primary.opacity(0.08),
                radius: 18,
                x: 0,
                y: 10
            )
    }
}
