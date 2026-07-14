//
//  AIInsightCard.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct AIInsightCard: View {
    
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            
            ZStack {
                Circle()
                    .fill(AppColors.card)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(AppColors.bubbleBorder, lineWidth: 1)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.primary)
            }
            .padding(.top, 10)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
        }
    }
}
