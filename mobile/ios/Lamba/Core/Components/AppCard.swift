//
//  AppCard.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AppCard<Content: View>: View {
    
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = AppRadius.xxl
    
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .appCard(
                padding: padding,
                cornerRadius: cornerRadius
            )
    }
}

extension View {
    func appCard(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = AppRadius.xxl
    ) -> some View {
        self
            .padding(padding)
            .background(AppColors.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.bubbleBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
