//
//  AuthViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var currentUser: UserResponse?
    
    private let tokenKey = "auth_token"
    
    var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    init() {
        if token != nil {
            isLoggedIn = true
        }
    }
    
    func register(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await AuthAPIService.shared.register(
                email: email,
                password: password
            )
            
            saveSession(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await AuthAPIService.shared.login(
                email: email,
                password: password
            )
            
            saveSession(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchCurrentUser() async {
        guard let token else { return }
        
        do {
            currentUser = try await AuthAPIService.shared.getCurrentUser(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        currentUser = nil
        isLoggedIn = false
    }
    
    private func saveSession(_ response: AuthResponse) {
        UserDefaults.standard.set(response.token, forKey: tokenKey)
        currentUser = response.user
        isLoggedIn = true
    }
}
