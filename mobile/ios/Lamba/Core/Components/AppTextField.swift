//
//  AppTextField.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AppTextField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String

    var trailingIcon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textInputAutocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.6)
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFocused ? AppTheme.primary : AppTheme.primary.opacity(0.5))
                    .frame(width: 22)

                TextField(placeholder, text: $text)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.foreground)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .focused($isFocused)

                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.mutedForeground)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.mediumRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.mediumRadius)
                    .stroke(
                        isFocused ? AppTheme.primary : AppTheme.primary.opacity(0.10),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}
