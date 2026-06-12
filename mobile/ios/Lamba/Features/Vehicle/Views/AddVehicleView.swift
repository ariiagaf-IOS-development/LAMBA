//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct AddVehicleView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var manufacturer = ""
    @State private var modelName = ""
    @State private var year = ""
    @State private var mileage = ""
    @State private var vinNumber = ""

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        header
                        form
                        bottomAction
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                appViewModel.logout()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppTheme.muted, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            }

            Spacer()

            Text("Add Vehicle")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(AppTheme.foreground)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(AppTheme.card.opacity(0.82))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.primary.opacity(0.05))
                .frame(height: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(AppTheme.primary)
                .frame(width: 80, height: 8)
                .padding(.bottom, 2)

            Text("Create Your")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppTheme.foreground)

            Text("Digital Twin")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppTheme.primary)

            Text("Enter your vehicle's DNA to initialize the LAMBA AI sync.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .lineSpacing(4)
                .padding(.top, 2)
        }
    }

    private var form: some View {
        VStack(spacing: 22) {
            AppTextField(
                title: "Manufacturer",
                placeholder: "e.g. Tesla",
                icon: "building.2.fill",
                text: $manufacturer,
                trailingIcon: "chevron.down"
            )

            AppTextField(
                title: "Model Name",
                placeholder: "e.g. Model 3",
                icon: "car.fill",
                text: $modelName
            )

            HStack(alignment: .top, spacing: 16) {
                AppTextField(
                    title: "Year",
                    placeholder: "2024",
                    icon: "calendar",
                    text: $year
                )
                .keyboardType(.numberPad)

                AppTextField(
                    title: "Mileage (km)",
                    placeholder: "12,500",
                    icon: "speedometer",
                    text: $mileage
                )
                .keyboardType(.numberPad)
            }

            AppTextField(
                title: "VIN Number",
                placeholder: "17-digit code",
                icon: "key.fill",
                text: $vinNumber
            )
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 22) {
            PrimaryButton("Sync Vehicle", icon: "arrow.clockwise") {
                appViewModel.completeVehicleCreation()
            }

            Text("Secure encrypted data sync")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(AppTheme.mutedForeground)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 12)
    }
}
