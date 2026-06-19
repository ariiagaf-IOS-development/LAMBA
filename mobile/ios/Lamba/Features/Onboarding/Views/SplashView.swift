//
//  SplashView.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct SplashView: View {
    
    @State private var progressWidth: CGFloat = 20
    
    var body: some View {
        ZStack {
            AppColors.splashBackground
                .ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Image("splash_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.bottom, AppSpacing.sm)
                Text("LAMBA")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                Text("AUTONOMOUS DIGITAL TWIN")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.primary)
                    .tracking(4)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        AppColors.primary.opacity(0.05)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(AppColors.primary.opacity(0.10), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                
            }
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999)
                            .fill(AppColors.textSecondary)
                            .frame(width: 200, height: 6)
                        
                        RoundedRectangle(cornerRadius: 999)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.primary,
                                        Color(hex: "0EA5E9")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 6)
                    }
                    
                    Text("SYNCING NEURAL LINK...")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(AppColors.mutedForeground)
                        .tracking(2)
                }
                .padding(.bottom, 60)
            }
           
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                progressWidth = 200
            }
        }
    }
}
