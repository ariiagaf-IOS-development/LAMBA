//
//  PrimaryButton.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .black))

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.mediumRadius))
            .shadow(
                color: isDisabled ? .clear : AppTheme.primary.opacity(0.25),
                radius: 18,
                x: 0,
                y: 10
            )
            .opacity(isDisabled ? 0.55 : 1)
        }
        .disabled(isDisabled)
    }

    private var buttonBackground: some View {
        LinearGradient(
            colors: [
                AppTheme.primary,
                Color.indigo
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
