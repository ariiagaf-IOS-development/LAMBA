//
//  SignUpView.swift
//  Lamba
//
//  Created by Арина Агафонова on 24.06.2026.
//

import SwiftUI

struct SignUpView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    let onBack: () -> Void
    let onSignIn: () -> Void
    
    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }

    private var isPasswordValid: Bool {
        password.count >= 8
    }

    private var isFirstNameValid: Bool {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var isLastNameValid: Bool {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var isFormValid: Bool {
        isFirstNameValid && isLastNameValid && isEmailValid && isPasswordValid
    }

    private var validationMessage: String? {
        if firstName.isEmpty && lastName.isEmpty && email.isEmpty && password.isEmpty {
            return nil
        }

        if !isFirstNameValid {
            return "Enter your first name."
        }

        if !isLastNameValid {
            return "Enter your last name."
        }
        
        if !isEmailValid {
            return "Enter a valid email address."
        }
        
        if !isPasswordValid {
            return "Password must contain at least 8 characters."
        }
        
        return nil
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
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
                        .frame(height: 12)
                    
                    AuthLogoIcon()
                        .padding(.horizontal, 32)
                    
                    VStack(alignment: .leading, spacing: -12) {
                        Text("SIGN UP")
                            .font(.system(size: 60, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(-2)
                        
                        VStack(alignment: .leading, spacing: -12) {
                            Text("MEET YOUR CAR’S")
                            Text("DIGITAL TWIN")
                        }
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .tracking(-1)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 22)
                    
                    Text("Track trips, refueling, repairs, and maintenance predictions in one clean AI-powered assistant.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: 323, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        AuthFieldLabel("FIRST NAME")

                        AuthTextField(
                            text: $firstName,
                            placeholder: "Arina",
                            systemImage: "person.fill",
                            isSecure: false
                        )

                        AuthFieldLabel("LAST NAME")
                            .padding(.top, 8)

                        AuthTextField(
                            text: $lastName,
                            placeholder: "Agafonova",
                            systemImage: "person.text.rectangle.fill",
                            isSecure: false
                        )
                        
                        AuthFieldLabel("EMAIL ADDRESS")
                            .padding(.top, 8)
                        
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
                        
                        Text("Use at least 8 characters.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.leading, 4)
                        
                        if let validationMessage {
                            Text(validationMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                                .padding(.top, 4)
                        } else if let errorMessage = authViewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.orange)
                                .padding(.top, 4)
                        }
                        
                        Button {
                            
                            guard isFormValid else { return }
                            
                            Task {
                                await authViewModel.register(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                                    password: password,
                                    firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            }
                        } label: {
                            Text(authViewModel.isLoading ? "CREATING..." : "CREATE ACCOUNT")
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
                            onSignIn()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .font(.system(size: 15, weight: .medium))
                                
                                Text("Sign in")
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
                    .padding(.top, 30)
                    .padding(.bottom, 28)
                }
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
        .onChange(of: firstName) { _, _ in
            authViewModel.clearError()
        }
        .onChange(of: lastName) { _, _ in
            authViewModel.clearError()
        }
        .hideKeyboardOnTap()
    }
}
