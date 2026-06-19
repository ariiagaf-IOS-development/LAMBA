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
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
            
            Text(accentTitle)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(AppColors.primary)
            
            Text(subtitle)
                .font(AppTypography.h3)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .padding(.top, 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }
}
