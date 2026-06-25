//
//  AuthComponents.swift
//  Lamba
//
//  Created by Арина Агафонова on 24.06.2026.
//

import SwiftUI

struct AuthLogoIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.gradientStart,
                            AppColors.gradientEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .shadow(
                    color: AppColors.primary.opacity(0.20),
                    radius: 20,
                    x: 0,
                    y: 20
                )
            
            Image(systemName: "car.front.waves.up.fill")
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

struct AuthFieldLabel: View {
    
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(2)
    }
}

struct AuthTextField: View {
    
    @Binding var text: String
    
    let placeholder: String
    let systemImage: String
    let isSecure: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 18)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(placeholder.contains("@") ? .emailAddress : .default)
            }
        }
        .frame(minHeight: 24)
        .appCard()
    }
}
