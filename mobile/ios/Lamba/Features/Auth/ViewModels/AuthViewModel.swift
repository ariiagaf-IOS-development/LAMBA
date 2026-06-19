//
//  AuthViewModel.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import Foundation
import Combine

class AuthViewModel: ObservableObject {
    
    @Published var isLoggedIn: Bool = false
    
    func login() {
        isLoggedIn = true
    }
}
