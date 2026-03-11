//
//  UpcomingView.swift
//  ToDo Tickler
//

import EventKit
import SwiftUI

struct UpcomingView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(LocationManager.self) private var locationManager
    @State private var showingNewReminder = false
    @State private var newReminder: EKReminder?

    var body: some View {
        NavigationStack {
            Group {
                if store.upcomingReminders.isEmpty && !store.isLoading {
                    ContentUnavailableView(
                        "No Upcoming Tasks",
                        systemImage: "calendar.badge.clock",
                        description: Text("No tasks are scheduled to start or be done on a future date.")
                    )
                } else {
                    reminderList
                }
            }
            .navigationTitle("Upcoming")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewReminder) {
                        Label("New Reminder", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: String.self) { identifier in
                if let reminder = store.reminder(withIdentifier: identifier) {
                    ReminderDetailView(reminder: reminder)
                }
            }
            .sheet(isPresented: $showingNewReminder) {
                if let reminder = newReminder {
                    NavigationStack {
                        ReminderDetailView(reminder: reminder, isNew: true)
                    }
                }
            }
            .refreshable {
                await store.fetchAllReminders()
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private var reminderList: some View {
        List {
            ForEach(store.upcomingReminders, id: \.calendarItemIdentifier) { reminder in
                let meta = store.metadata(for: reminder)
                let isNear = meta.doAtLocation.map { locationManager.isNear($0) } ?? false

                NavigationLink(value: reminder.calendarItemIdentifier) {
                    ReminderRowView(
                        reminder: reminder,
                        isNearLocation: isNear,
                        onToggleComplete: { try? store.toggleComplete(reminder) }
                    )
                }
                .swipeActions(edge: .leading) {
                    Button {
                        try? store.toggleToday(reminder)
                    } label: {
                        let isMarkedToday = store.metadata(for: reminder).markedToday == true
                        Label("Today", systemImage: isMarkedToday ? "flag.slash" : "flag.fill")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        try? store.toggleComplete(reminder)
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
    }

    private func createNewReminder() {
        newReminder = store.createReminder()
        showingNewReminder = true
    }
}
