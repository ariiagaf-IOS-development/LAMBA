//
//  RootView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

enum AuthScreen {
    case welcome
    case signIn
    case signUp
}

struct RootView: View {
    
    @State private var showSplash = true
    
    @State private var authScreen: AuthScreen = .welcome
    
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
                switch authScreen {
                case .welcome:
                    WelcomeView(
                        onGetStarted: {
                            authViewModel.clearError()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .signUp
                            }
                        },
                        onSignIn: {
                            authViewModel.clearError()
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .signIn
                            }
                        }
                    )
                    
                case .signIn:
                    SignInView(
                        onBack: {
                            authViewModel.clearError()

                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .welcome
                            }
                        },
                        onCreateAccount: {
                            authViewModel.clearError()

                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .signUp
                            }
                        }
                        )
                        .environmentObject(authViewModel)

                case .signUp:
                    SignUpView(
                        onBack: {
                            authViewModel.clearError()

                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .welcome
                            }
                        },
                        onSignIn: {
                            authViewModel.clearError()

                            withAnimation(.easeInOut(duration: 0.3)) {
                                authScreen = .signIn
                            }
                        }
                        )
                        .environmentObject(authViewModel)
                }
            }
            
            // 2. MAIN APP
            else {
                MainTabView()
                    .environmentObject(vehicleViewModel)
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            authViewModel.clearError()
        }
    }
}

//import SwiftUI
//
//enum AuthScreen {
//    case welcome
//    case signIn
//    case signUp
//}
//
//struct RootView: View {
//    
//    @State private var showSplash = true
//    
//    @State private var authScreen: AuthScreen = .welcome
//    
//    @StateObject private var authViewModel = AuthViewModel()
//    @StateObject private var vehicleViewModel = VehicleViewModel()
//    
//    var body: some View {
//        Group {
//            if showSplash {
//                SplashView()
//                    .transition(.opacity)
//                    .onAppear {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//                            withAnimation(.easeInOut(duration: 0.4)) {
//                                showSplash = false
//                            }
//                        }
//                    }
//            } else {
//                MainTabView()
//                    .environmentObject(vehicleViewModel)
//                    .environmentObject(authViewModel)
//            }
//        }
//        .onAppear {
//            authViewModel.clearError()
//        }
//    }
//}
