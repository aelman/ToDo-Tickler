//
//  AllRemindersView.swift
//  ToDo Tickler
//

import EventKit
import SwiftUI

struct AllRemindersView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                    NavigationLink(value: calendar.calendarIdentifier) {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                            Spacer()
                            Text("\(store.reminders(in: calendar).count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .navigationDestination(for: String.self) { calendarID in
                if let calendar = store.calendars.first(where: { $0.calendarIdentifier == calendarID }) {
                    CalendarRemindersListView(calendar: calendar)
                }
            }
            .refreshable {
                await store.fetchAllReminders()
            }
        }
    }
}

// MARK: - Calendar Reminders List

struct CalendarRemindersListView: View {
    let calendar: EKCalendar
    @Environment(ReminderStore.self) private var store
    @Environment(LocationManager.self) private var locationManager
    @State private var showingNewReminder = false
    @State private var newReminder: EKReminder?

    private var remindersInCalendar: [EKReminder] {
        store.reminders(in: calendar)
            .sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    var body: some View {
        List {
            if remindersInCalendar.isEmpty {
                ContentUnavailableView(
                    "No Reminders",
                    systemImage: "list.bullet",
                    description: Text("This list has no incomplete reminders.")
                )
            } else {
                ForEach(remindersInCalendar, id: \.calendarItemIdentifier) { reminder in
                    let meta = store.metadata(for: reminder)
                    let isNear = meta.doAtLocation.map { locationManager.isNear($0) } ?? false

                    NavigationLink(value: reminder.calendarItemIdentifier) {
                        ReminderRowView(
                            reminder: reminder,
                            isNearLocation: isNear,
                            onToggleComplete: { try? store.toggleComplete(reminder) }
                        )
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            try? store.delete(reminder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

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
        .navigationTitle(calendar.title)
        .navigationDestination(for: String.self) { identifier in
            if let reminder = store.reminder(withIdentifier: identifier) {
                ReminderDetailView(reminder: reminder)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewReminder) {
                    Label("New Reminder", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewReminder) {
            if let reminder = newReminder {
                NavigationStack {
                    ReminderDetailView(reminder: reminder, isNew: true)
                }
            }
        }
    }

    private func createNewReminder() {
        newReminder = store.createReminder(in: calendar)
        showingNewReminder = true
    }
}
