//
//  MainTabView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

enum AppTab {
    case ai
    case log
    case vehicle
    case care
}

struct MainTabView: View {
    
    @State private var selectedTab: AppTab = .ai
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            AIChatView(selectedTab: $selectedTab)
                .tabItem {
                    Label("AI", systemImage: "message.fill")
                }
                .tag(AppTab.ai)
            
            LogView()
                .tabItem {
                    Label("LOG", systemImage: "clock.fill")
                }
                .tag(AppTab.log)
            
            VehicleProfileView()
                .tabItem {
                    Label("VEHICLE", systemImage: "car.fill")
                }
                .tag(AppTab.vehicle)
            
            CareOverviewView()
                .tabItem {
                    Label("CARE", systemImage: "heart.fill")
                }
                .tag(AppTab.care)
        }
    }
}
