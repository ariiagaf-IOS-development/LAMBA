//
//  AIChatView 2.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct AIChatView: View {
    
    @State private var messageText: String = ""
    
    var body: some View {
        
        ZStack {
            
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // ================= HEADER =================
                HStack(spacing: 12) {
                    
                    HeaderIcon(systemName: "bolt.fill")
                    
                    Text("LAMBA AI")
                        .font(AppTypography.menu)
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        
                        Circle()
                            .fill(AppColors.green)
                            .frame(width: 6, height: 6)

                        Text("LINK ACTIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(AppColors.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "ECFDF5"))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.pill)
                            .stroke(Color(hex: "D0FAE5"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(height: 65)
                .background(AppColors.card)
                
                // ================= HERO =================
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text("HI, ARI")
                        .font(AppTypography.h1)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, 20)
                    
                    Text("How can I help with your car today?")
                        .font(AppTypography.h2)
                        .italic()
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: 240, alignment: .leading)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                
                Spacer().frame(height: 20)
                
                // ================= MAIN CARD =================
                VStack(alignment: .leading, spacing: 14) {
                    AIInsightCard(
                        text: "Your vehicle looks stable today. Brake pads are healthy, but the next service check is recommended in 1,240 km."
                    )
                    
                    ActionCard(
                        iconName: "waveform.path.ecg",
                        title: "View detailed health report",
                        subtitle: "Open full vehicle health overview"
                    ) {
                        print("Open health report")
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
            }
            
            // ================= INPUT FLOATING =================
            VStack {
                Spacer()
                
                AIInputBar(text: $messageText)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 10)
            }
        }
    }
}

