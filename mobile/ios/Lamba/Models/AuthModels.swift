//
//  AuthModels.swift
//  Lamba
//
//  Created by Арина Агафонова on 24.06.2026.
//

import Foundation

struct AuthRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let tokenType: String
    let user: UserResponse
}

struct UserResponse: Decodable {
    let id: Int
    let email: String
    let createdAt: String?
}
