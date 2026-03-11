//
//  ContentView.swift
//  ToDo Tickler
//

import EventKit
import SwiftUI

struct ContentView: View {
    @Environment(ReminderStore.self) private var store

    var body: some View {
        Group {
            switch store.authorizationStatus {
            case .fullAccess:
                mainTabView
            case .notDetermined:
                ProgressView("Requesting access to Reminders...")
            default:
                permissionDeniedView
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            Tab("Today", systemImage: "star.fill") {
                TodayView()
            }
            Tab("Available", systemImage: "tray.full") {
                AvailableView()
            }
            Tab("Upcoming", systemImage: "calendar.badge.clock") {
                UpcomingView()
            }
            Tab("Lists", systemImage: "list.bullet") {
                AllRemindersView()
            }
        }
        #if os(iOS)
        .tabViewStyle(.sidebarAdaptable)
        #endif
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Reminders Access Required", systemImage: "lock.shield")
        } description: {
            Text("ToDo Tickler needs access to your Reminders to display and manage your tasks. Please grant access in Settings.")
        } actions: {
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #elseif os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
                #endif
            }
        }
    }
}

