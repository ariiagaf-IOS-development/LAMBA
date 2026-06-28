//
//  RootView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct RootView: View {
    
    @State private var showSplash = true
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var vehicleViewModel = VehicleViewModel()
    
    var body: some View {
        Group {
            
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            }
            
            // 1. NOT LOGGED IN
            else if !authViewModel.isLoggedIn {
                WelcomeView(
                    onGetStarted: {
                        authViewModel.login()
                    },
                    onSignIn: {
                        authViewModel.login()
                    }
                )
                .environmentObject(authViewModel)
            }
            
            // 2. NO VEHICLE
            else if !vehicleViewModel.hasVehicle {
                AddVehicleView()
                    .environmentObject(vehicleViewModel)
                    .environmentObject(authViewModel)
            }
            
            // 3. MAIN APP
            else {
                MainTabView()
                    .environmentObject(vehicleViewModel)
                    .environmentObject(authViewModel)
            }
        }
    }
}
