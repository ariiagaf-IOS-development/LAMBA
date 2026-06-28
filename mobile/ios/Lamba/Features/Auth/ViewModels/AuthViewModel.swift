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
    
    private let hasLaunchedBeforeKey = "has_launched_before"
    
    var token: String? {
        KeychainService.shared.read(for: tokenKey)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    init() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        
        if !hasLaunchedBefore {
            KeychainService.shared.delete(for: tokenKey)
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        }
        
        if token != nil {
            isLoggedIn = true
        }
    }
    
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await AuthAPIService.shared.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
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
        KeychainService.shared.save(response.token, for: tokenKey)
        currentUser = response.user
        isLoggedIn = true
    }
}
