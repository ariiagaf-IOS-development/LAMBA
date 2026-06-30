//
//  SignInView.swift.swift
//  Lamba
//
//  Created by Арина Агафонова on 24.06.2026.
//

import SwiftUI

struct SignInView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let onBack: () -> Void
    let onCreateAccount: () -> Void
    
    @State private var email: String = ""
    @State private var password: String = ""
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                
                HStack {
                    Button {
                        onBack()
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
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Spacer()
                    .frame(height: 20)
                
                AuthLogoIcon()
                    .padding(.horizontal, 32)
                
                VStack(alignment: .leading, spacing: -12) {
                    Text("SIGN IN")
                        .font(.system(size: 60, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(-2)
                    
                    Text("WELCOME BACK")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .tracking(-1)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                
                Text("Continue to your vehicle AI assistant.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                
                VStack(alignment: .leading, spacing: 14) {
                    AuthFieldLabel("EMAIL ADDRESS")
                    
                    AuthTextField(
                        text: $email,
                        placeholder: "agaarina@lamba.ai",
                        systemImage: "envelope.fill",
                        isSecure: false
                    )
                    
                    AuthFieldLabel("PASSWORD")
                        .padding(.top, 8)
                    
                    AuthTextField(
                        text: $password,
                        placeholder: "••••••••",
                        systemImage: "lock.fill",
                        isSecure: true
                    )
                    
//                    HStack {
//                        Spacer()
//                        Button {
//                            print("forgot password")
//                        } label: {
//                            Text("FORGOT PASSWORD?")
//                                .font(.system(size: 11, weight: .black))
//                                .foregroundStyle(AppColors.primary)
//                                .tracking(0.8)
//                        }
//                        .buttonStyle(.plain)
//                    }
                    
                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.orange)
                            .padding(.top, 4)
                    }
                    
                    Button {
                        Task {
                            await authViewModel.login(
                                email: email,
                                password: password
                            )
                        }
                    } label: {
                        Text(authViewModel.isLoading ? "SIGNING IN..." : "SIGN IN")
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
                                color: AppColors.primary.opacity(0.25),
                                radius: 18,
                                x: 0,
                                y: 12
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFormValid || authViewModel.isLoading)
                    .opacity((isFormValid && !authViewModel.isLoading) ? 1 : 0.55)
                    .padding(.top, 8)
                    
                    Button {
                        onCreateAccount()
                    } label: {
                        HStack(spacing: 4) {
                            Text("New to LAMBA?")
                                .font(.system(size: 15, weight: .medium))
                            
                            Text("Create account")
                                .font(.system(size: 15, weight: .bold))
                                .underline()
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 32)
                .padding(.top, 34)
                
                Spacer()
            }
        }
        .onAppear {
            authViewModel.clearError()
        }
        .onChange(of: email) { _, _ in
            authViewModel.clearError()
        }
        .onChange(of: password) { _, _ in
            authViewModel.clearError()
        }
        .hideKeyboardOnTap()
    }
}
