//
//  AddVehicleView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

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
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        form
                        bottomAction
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
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
                    .frame(width: 44, height: 44)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }

            Spacer()

            Text("Add Vehicle")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppTheme.foreground)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(AppTheme.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.primary.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(AppTheme.primary)
                .frame(width: 80, height: 8)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                Text("Create Your")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(AppTheme.foreground)

                Text("Digital Twin")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(AppTheme.primary)
            }

            Text("Enter your vehicle's DNA to initialize the LAMBA AI sync.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedForeground)
                .lineSpacing(4)
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

                AppTextField(
                    title: "Mileage (km)",
                    placeholder: "12,500",
                    icon: "speedometer",
                    text: $mileage
                )
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
