//
//  ToDo_TicklerApp.swift
//  ToDo Tickler
//

import SwiftUI

@main
struct ToDo_TicklerApp: App {
    @State private var reminderStore = ReminderStore()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(reminderStore)
                .environment(locationManager)
                .task {
                    await reminderStore.requestAccess()
                    locationManager.startUpdating()
                }
        }
    }
}
