//
//  WelcomeView.swift
//  Lamba
//
//  Created by Арина Агафонова on 21.06.2026.
//

import SwiftUI

struct WelcomeView: View {
    
    let onGetStarted: () -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        ZStack {
            AppColors.splashBackground
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                Image("welcome_car")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 1.12)
                    .rotationEffect(.degrees(-5.79))
                    .offset(
                        x: geometry.size.width * -0.06,
                        y: geometry.size.height * 0.30
                    )
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                
                Spacer()
                    .frame(height: 118)
                
                VStack(alignment: .leading, spacing: -12) {
                    Text("LAMBA")
                        .font(.system(size: 60, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(-2)
                    
                    Text("car’s AI assistant")
                        .textCase(.uppercase)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .tracking(-1)
                }
                .padding(.horizontal, 32)
                
                Text("Track service history and maintenance predictions.")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: 280, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        onGetStarted()
                    } label: {
                        Text("GET STARTED")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .tracking(1.4)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(
                                LinearGradient(
                                    colors: [
                                        AppColors.gradientStart,
                                        AppColors.gradientEnd
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
                            .shadow(
                                color: AppColors.primary.opacity(0.30),
                                radius: 25,
                                x: 0,
                                y: 16
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onSignIn()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Sign in")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .underline()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
    }
}
