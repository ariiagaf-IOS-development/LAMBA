//
//  MainTabView.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }

            TimelineView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Timeline")
                }

            VehicleProfileView()
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehicle")
                }

            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }

            PredictionsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Predictions")
                }
        }
    }
}
