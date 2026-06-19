//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI
import PhotosUI

struct AddVehicleView: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var mileage: String = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var vehicleImage: Image?
    
    private var isFormValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !mileage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                AppHeaderView(title: "CREATE VEHICLE") {
                    authViewModel.logout()
                }
                
                ScreenHeroView(
                    title: "CREATE YOUR",
                    accentTitle: "DIGITAL TWIN",
                    subtitle: "Add your vehicle details to initialize LAMBA AI sync."
                )
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        VehiclePhotoUploadField(
                            selectedPhoto: $selectedPhoto,
                            vehicleImage: vehicleImage
                        )
                        
                        VehicleFieldSection(
                            title: "VEHICLE NODE (BRAND)",
                            placeholder: "e.g. Tesla",
                            text: $brand
                        )
                        
                        VehicleFieldSection(
                            title: "MODEL NAME",
                            placeholder: "e.g. Model 3",
                            text: $model
                        )
                        
                        HStack(spacing: 12) {
                            VehicleFieldSection(
                                title: "PRODUCTION YEAR",
                                placeholder: "2022",
                                text: $year,
                                keyboardType: .numberPad
                            )
                            .frame(maxWidth: .infinity)

                            VehicleFieldSection(
                                title: "MILEAGE",
                                placeholder: "48,000 km",
                                text: $mileage,
                                keyboardType: .numberPad
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.top, 40)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                PrimaryActionButton(
                    title: "INITIALIZE PROTOCOL",
                    colors: isFormValid
                    ? [
                        AppColors.gradientStart,
                        AppColors.gradientEnd
                    ]
                    : [
                        AppColors.textSecondary.opacity(0.5),
                        AppColors.textSecondary.opacity(0.5)
                    ]
                ) {
                    if isFormValid {
                        vehicleViewModel.createVehicle()
                    }
                }
                .disabled(!isFormValid)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
                .background(AppColors.background)
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    vehicleImage = Image(uiImage: uiImage)
                }
            }
        }
    }
}

private struct VehicleInputField: View {
    
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textPrimary)
            .frame(minHeight: 24)
            .appCard()
    }
}

private struct VehicleFieldSection: View {
    
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(2)
            
            VehicleInputField(
                placeholder: placeholder,
                text: $text,
                keyboardType: keyboardType
            )
        }
    }
}

private struct VehiclePhotoUploadField: View {
    
    @Binding var selectedPhoto: PhotosPickerItem?
    let vehicleImage: Image?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("UPLOAD VEHICLE PHOTO")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(2)
            
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .fill(AppColors.background)
                            .frame(width: 52, height: 52)
                        
                        if let vehicleImage {
                            vehicleImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicleImage == nil ? "Add a photo to personalize your digital twin" : "Vehicle photo added")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineSpacing(3)
                        
                        Text(vehicleImage == nil ? "Tap to upload" : "Tap to change photo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                    }
                    
                    Spacer()
                }
                .appCard()
            }
            .buttonStyle(.plain)
        }
    }
}
