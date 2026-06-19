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
                        .foregroundColor(Color(hex: "111827"))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        
                        Circle()
                            .fill(Color(hex: "00BC7D"))
                            .frame(width: 6, height: 6)
                        
                        Text("LINK ACTIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color(hex: "00BC7D"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "ECFDF5"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(Color(hex: "D0FAE5"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(height: 65)
                .background(Color.white)
                
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
                AIInsightCard(
                    text: "Your vehicle looks stable today. Brake pads are healthy, but the next service check is recommended in 1,240 km."
                )
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
            }
            
            // ================= INPUT FLOATING =================
            VStack {
                Spacer()
                
                HStack(spacing: AppSpacing.sm) {
                    
                    Circle()
                        .fill(Color(hex: "F1F5F9"))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.textSecondary)
                        )
                    
                    TextField("Ask LAMBA AI...", text: $messageText)
                        .font(AppTypography.subtitle)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.primary,
                                    Color(hex: "393B8B")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .foregroundColor(.white)
                        )
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }
}

