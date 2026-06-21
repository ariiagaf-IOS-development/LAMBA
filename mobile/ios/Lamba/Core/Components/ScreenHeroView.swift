//
//  ScreenHeroView.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct ScreenHeroView: View {
    
    let title: String
    let accentTitle: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: -17) {
            Text(title)
                .font(AppTypography.h1)
                .foregroundStyle(AppColors.textPrimary)
                .textCase(.uppercase)
            
            Text(accentTitle)
                .font(AppTypography.h1)
                .foregroundStyle(AppColors.primary)
                .textCase(.uppercase)
            
            Text(subtitle)
                .font(AppTypography.h3)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .padding(.top, 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }
}
