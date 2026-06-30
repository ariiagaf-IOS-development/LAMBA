//
//  AppColors.swift
//  Lamba
//
//  Created by Арина Агафонова on 18.06.2026.
//

import SwiftUI

enum AppColors {
    
    // MARK: - Backgrounds
    static let splashBackground = Color(hex: "FFFFFF")
    static let background = Color(hex: "F1F5F9")
    static let card = Color(hex: "FFFFFF")
    
    // MARK: - Text
    static let textPrimary = Color(hex: "111827")   // headers
    static let textSecondary = Color(hex: "62748E") // subtitles
    static let textMuted = Color(hex: "94A3B8")
    static let mutedForeground = Color(hex: "90A1B9")
    
    // MARK: - Primary Accent (MAIN)
    static let primary = Color(hex: "6366F1")
        
    // MARK: - Extra accents
    static let teal = Color(hex: "0092B8")
    static let green = Color(hex: "00786F")
    
    static let yellow = Color(hex: "FE9A00")
    static let orange = Color(hex: "CA3500")
    static let red = Color(hex: "DC2626")
    
    // MARK: - Risk levels
    static let riskLow = green
    static let riskMedium = yellow
    static let riskHigh = red
    
    // MARK: - Gradient buttons
    static let gradientStart = Color(hex: "6366F1")
    static let gradientEnd = Color(hex: "393B8B")
    
    static let userBubble = Color(hex: "6366F1")
    static let aiBubble = Color.white
    static let bubbleBorder = Color.black.opacity(0.06)
}
