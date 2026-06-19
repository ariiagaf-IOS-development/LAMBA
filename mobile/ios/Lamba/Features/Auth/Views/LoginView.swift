//
//  LoginView.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("LOGIN")
                .font(.largeTitle)
                .bold()
            
            Button("Sign In") {
                authViewModel.login()
            }
        }
    }
}
