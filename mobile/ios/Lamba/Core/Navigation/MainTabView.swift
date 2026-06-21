//
//  MainTabView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct MainTabView: View {
    
    @EnvironmentObject var vehicleViewModel: VehicleViewModel
    
    var body: some View {
        TabView {
            
            AIChatView()
                .tabItem {
                    Label("AI", systemImage: "message.fill")
                }
            
            TimelineView()
                .tabItem {
                    Label("LOG", systemImage: "clock.fill")
                }
            
            VehicleProfileView()
                .tabItem {
                    Label("VEHICLE", systemImage: "car.fill")
                }
            
            CareOverviewView()
                .tabItem {
                    Label("CARE", systemImage: "heart.fill")
                }
        }
        .tint(AppColors.primary)
    }
}
