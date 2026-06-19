//
//  AppHeaderView.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct AppHeaderView: View {
    
    let title: String
    var onBackTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Button {
                onBackTap?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.bubbleBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .textCase(.uppercase)
                .tracking(1.5)
            
            Spacer()
            
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(AppColors.card.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(AppColors.bubbleBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
