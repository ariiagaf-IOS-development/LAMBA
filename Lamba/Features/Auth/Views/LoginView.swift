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
        VStack(spacing: 16) {
            Text("LAMBA")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Login screen")

            Button("Login") {
                appViewModel.login()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
