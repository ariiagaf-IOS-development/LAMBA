//
//  UserProfileView.swift
//  Lamba
//

import SwiftUI

struct UserProfileView: View {
    
    @Binding var selectedTab: AppTab
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    @State private var showsLogoutConfirmation = false
    @State private var showsPersonalityPicker = false
    @State private var showsManageVehicles = false
    @State private var showsEditVehicle = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    ScreenHeroView(
                        title: "DRIVER",
                        accentTitle: "PROFILE",
                        subtitle: "Account, garage state and session controls for your LAMBA workspace.",
                        topPadding: 12
                    )
                    
                    VStack(spacing: AppSpacing.lg) {
                        UserIdentityCard(user: authViewModel.currentUser)
                        
                        Button {
                            showsManageVehicles = true
                        } label: {
                            ProfileMetricsGrid(
                                vehicleCount: vehicleViewModel.vehicles.count,
                                activeVehicle: vehicleViewModel.activeVehicle
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            if vehicleViewModel.activeVehicle != nil {
                                showsEditVehicle = true
                            } else {
                                selectedTab = .vehicle
                            }
                        } label: {
                            CurrentVehicleProfileCard(vehicle: vehicleViewModel.activeVehicle)
                        }
                        .buttonStyle(.plain)
                        
                        if let activeVehicle = vehicleViewModel.activeVehicle {
                            VehiclePersonalityCard(
                                personality: vehicleViewModel.personality(for: activeVehicle),
                                vehicleName: "\(activeVehicle.brand) \(activeVehicle.model)"
                            ) {
                                showsPersonalityPicker = true
                            }
                        }
                        
                        ProfileActionCard(
                            title: "SIGN OUT",
                            subtitle: "End this session and return to welcome flow.",
                            icon: "rectangle.portrait.and.arrow.right",
                            tint: AppColors.red
                        ) {
                            showsLogoutConfirmation = true
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeaderView(
                config: .init(
                    title: "PROFILE",
                    leftIcon: "person.crop.circle.fill",
                    showsBackButton: false
                ),
                actions: .init()
            )
        }
        .confirmationDialog(
            "Sign out of LAMBA?",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                vehicleViewModel.clearSessionState()
                authViewModel.logout()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local session will be cleared on this device.")
        }
        .task {
            if authViewModel.currentUser == nil {
                await authViewModel.fetchCurrentUser()
            }
        }
        .sheet(isPresented: $showsPersonalityPicker) {
            if let activeVehicle = vehicleViewModel.activeVehicle {
                VehiclePersonalityPickerView(
                    vehicle: activeVehicle,
                    selectedPersonality: vehicleViewModel.personality(for: activeVehicle),
                    onSelect: { personality in
                        vehicleViewModel.setPersonality(personality, for: activeVehicle.id)
                        showsPersonalityPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showsManageVehicles) {
            ManageVehiclesView()
                .environmentObject(vehicleViewModel)
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showsEditVehicle) {
            AddVehicleView(
                mode: .edit,
                onClose: {
                    showsEditVehicle = false
                }
            )
            .environmentObject(vehicleViewModel)
            .environmentObject(authViewModel)
        }
    }
}

private struct UserIdentityCard: View {
    
    let user: UserResponse?
    
    private var initials: String {
        let first = user?.firstName?.first.map(String.init) ?? ""
        let last = user?.lastName?.first.map(String.init) ?? ""
        let combined = first + last
        
        if !combined.isEmpty {
            return combined.uppercased()
        }
        
        return user?.email.first.map { String($0).uppercased() } ?? "L"
    }
    
    private var displayName: String {
        let parts = [
            user?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
            user?.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        
        return parts.isEmpty ? "LAMBA Driver" : parts.joined(separator: " ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    
                    Text(initials)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACCOUNT NODE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.2)
                    
                    Text(displayName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Text(user?.email ?? "Syncing account...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            
            HStack(spacing: AppSpacing.sm) {
                ProfileStatusPill(title: "AUTH", value: "ACTIVE", tint: AppColors.green)
                ProfileStatusPill(title: "TOKEN", value: "BASIC", tint: AppColors.primary)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct ProfileMetricsGrid: View {
    
    let vehicleCount: Int
    let activeVehicle: VehicleResponse?
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ProfileMetricCard(
                title: "GARAGE",
                value: "\(vehicleCount)",
                unit: vehicleCount == 1 ? "car" : "cars",
                icon: "car.2.fill",
                tint: AppColors.primary
            )
            
            ProfileMetricCard(
                title: "ACTIVE",
                value: activeVehicle == nil ? "--" : activeVehicleName,
                unit: "twin",
                icon: "dot.radiowaves.left.and.right",
                tint: activeVehicle == nil ? AppColors.orange : AppColors.green
            )
        }
    }
    
    private var activeVehicleName: String {
        guard let activeVehicle else { return "--" }
        return activeVehicle.model
    }
}

private struct ProfileMetricCard: View {
    
    let title: String
    let value: String
    let unit: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppColors.textMuted)
                    .tracking(1.1)
                
                Text(value)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                
                Text(unit)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
}

private struct CurrentVehicleProfileCard: View {
    
    let vehicle: VehicleResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "car.front.waves.up.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("CURRENT DIGITAL TWIN")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppColors.textMuted)
                        .tracking(1.2)
                    
                    Text(vehicleTitle)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                
                Spacer()
            }
            
            HStack(spacing: AppSpacing.sm) {
                ProfileStatusPill(title: "YEAR", value: yearText, tint: AppColors.primary)
                ProfileStatusPill(title: "MILEAGE", value: mileageText, tint: AppColors.teal)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(AppColors.bubbleBorder, lineWidth: 1)
        )
    }
    
    private var vehicleTitle: String {
        guard let vehicle else { return "No vehicle selected" }
        return "\(vehicle.brand) \(vehicle.model)"
    }
    
    private var yearText: String {
        guard let vehicle else { return "--" }
        return "\(vehicle.year)"
    }
    
    private var mileageText: String {
        guard let vehicle else { return "--" }
        return "\(vehicle.mileageKm.formatted()) km"
    }
}

private struct VehiclePersonalityCard: View {
    
    let personality: VehiclePersonality
    let vehicleName: String
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: personality.iconName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 48, height: 48)
                        .background(AppColors.primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PERSONALITY CORE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(1.2)
                        
                        Text(personality.title)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text(vehicleName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(AppColors.primary)
                }
                
                Text(personality.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(AppColors.primary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct VehiclePersonalityPickerView: View {
    
    let vehicle: VehicleResponse
    let selectedPersonality: VehiclePersonality
    let onSelect: (VehiclePersonality) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    ScreenHeroView(
                        title: "TWIN",
                        accentTitle: "MOOD",
                        subtitle: subtitle,
                        topPadding: 12
                    )
                    
                    VStack(spacing: AppSpacing.md) {
                        ForEach(availablePersonalities) { personality in
                            Button {
                                onSelect(personality)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    Image(systemName: personality.iconName)
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundStyle(personality == selectedPersonality ? .white : AppColors.primary)
                                        .frame(width: 48, height: 48)
                                        .background(personality == selectedPersonality ? AppColors.primary : AppColors.primary.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(personality.title)
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundStyle(AppColors.textPrimary)
                                        
                                        Text(personality.subtitle)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineSpacing(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if personality == selectedPersonality {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .black))
                                            .foregroundStyle(AppColors.primary)
                                    }
                                }
                                .padding(AppSpacing.lg)
                                .background(AppColors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(personality == selectedPersonality ? AppColors.primary.opacity(0.35) : AppColors.bubbleBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeaderView(
                config: .init(title: "PERSONALITY"),
                actions: .init(
                    onBackTap: {
                        dismiss()
                    }
                )
            )
            }
        }
        
        private var availablePersonalities: [VehiclePersonality] {
            VehiclePersonality.availableOptions(brand: vehicle.brand, model: vehicle.model)
        }
        
        private var subtitle: String {
            if VehiclePersonality.isBMW(brand: vehicle.brand, model: vehicle.model) {
                return "BMW detected. Roast mode is locked for this digital twin."
            }
            
            return "Choose how your \(vehicle.brand) \(vehicle.model) talks, reacts, and shows up in the app."
        }
    }

private struct ProfileActionCard: View {
    
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .tracking(1)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tint)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileStatusPill: View {
    
    let title: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(AppColors.textMuted)
                .tracking(1.1)
            
            Text(value)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
