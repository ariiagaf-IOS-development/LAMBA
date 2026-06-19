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
        
        Text(text)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(AppColors.textPrimary)
            .lineSpacing(6)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .frame(minHeight: 120)
            .background(
                LinearGradient(
                    colors: [
                        Color.white,
                        Color(hex: "F1F5F9")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
            )
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.02), radius: 20, x: 0, y: 10)
    }
}
