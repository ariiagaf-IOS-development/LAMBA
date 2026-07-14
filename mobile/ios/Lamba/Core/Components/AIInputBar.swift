//
//  AIInputBar.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct AIInputBar: View {
    
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            
            Circle()
                .fill(AppColors.background)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                )
            
            TextField("Ask LAMBA AI...", text: $text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
            
            Circle()
                .fill(AppColors.primary)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .padding(10)
        .background(AppColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
    }
}
