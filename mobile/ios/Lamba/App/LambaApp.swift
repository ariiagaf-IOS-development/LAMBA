//
//  LambaApp.swift
//  Lamba
//
//  Created by Арина Агафонова on 12.06.2026.
//

import SwiftUI

@main
struct LambaApp: App {
    init() {
        UserDefaults.standard.removeObject(forKey: "local_event_photos_by_event_id")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
