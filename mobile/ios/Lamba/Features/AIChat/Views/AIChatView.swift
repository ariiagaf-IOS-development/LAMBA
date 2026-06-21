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
                
                ZStack {
                    
                    Text("LAMBA AI")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    HStack {
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.card)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.bubbleBorder, lineWidth: 1)
                                )
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(AppColors.primary)
                        }
                        
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

