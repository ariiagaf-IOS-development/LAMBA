//
//  AppTypography.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

enum AppTypography {
    
    // Headers (111827, black 60 feel)
    static let h1 = Font.system(size: 40, weight: .black)
    static let h2 = Font.system(size: 20, weight: .bold)
    
    static let menu = Font.system(size: 14, weight: .bold)
    
    // Body
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    
    // Subtitles (62748E)
    static let subtitle = Font.system(size: 14, weight: .regular)
    
    // Buttons
    static let button = Font.system(size: 16, weight: .semibold)
    
    static let caption = Font.system(size: 12, weight: .bold)
}
