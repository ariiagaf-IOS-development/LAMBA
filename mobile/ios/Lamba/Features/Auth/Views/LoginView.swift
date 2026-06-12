//
//  LoginView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("LAMBA")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(AppTheme.foreground)

                AppCard {
                    VStack(spacing: 16) {
                        Text("Digital vehicle twin")
                            .font(.title3)
                            .fontWeight(.black)

                        Text("Track trips, refueling, repairs and predicted part health in one place.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppTheme.mutedForeground)

                        PrimaryButton("Continue", icon: "arrow.right") {
                            appViewModel.login()
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
