//
//  AppHeaderView.swift
//  Lamba
//
//  Created by Арина Агафонова on 19.06.2026.
//

import SwiftUI

struct AppHeaderView: View {
    
    // MARK: - CONFIG
    struct Config {
        var title: String
        var leftIcon: String = "chevron.left"
        var rightIcon: String? = nil
        
        var showsBackButton: Bool = true
        
        var backgroundOpacity: Double = 0.8
    }
    
    // MARK: - ACTIONS
    struct Actions {
        var onBackTap: (() -> Void)? = nil
        var onRightTap: (() -> Void)? = nil
    }
    
    let config: Config
    let actions: Actions
    
    var body: some View {
        HStack {
            
            // LEFT
            if config.showsBackButton {
                Button {
                    actions.onBackTap?()
                } label: {
                    Image(systemName: config.leftIcon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.bubbleBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                HeaderIcon(systemName: config.leftIcon)
            }
            
            Spacer()
            
            // TITLE
            Text(config.title)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(AppColors.textPrimary)
                .textCase(.uppercase)
                .tracking(1.5)
            
            Spacer()
            
            // RIGHT
            if let icon = config.rightIcon {
                Button {
                    actions.onRightTap?()
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.bubbleBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(
            AppColors.card.opacity(config.backgroundOpacity)
                .ignoresSafeArea(edges: .top)
        )
        .overlay(
            Rectangle()
                .fill(AppColors.bubbleBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
