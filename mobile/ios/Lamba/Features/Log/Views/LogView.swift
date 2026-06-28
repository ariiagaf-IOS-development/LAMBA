//
//  LogView.swift
//  Lamba
//
//  Created by Арина Агафонова on 28.06.2026.
//

import SwiftUI

struct LogView: View {
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(AppColors.primary)
                
                Text("LOG")
                    .font(AppTypography.h1)
                    .foregroundStyle(AppColors.textPrimary)
                
                Text("Vehicle activity timeline will appear here.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}
