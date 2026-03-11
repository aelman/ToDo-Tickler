//
//  ReminderDetailView.swift
//  ToDo Tickler
//

import CoreLocation
import EventKit
import SwiftUI

struct ReminderDetailView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let reminder: EKReminder
    var isNew: Bool = false

    // MARK: - Editable State

    @State private var title: String = ""
    @State private var userNotes: String = ""
    @State private var markedToday: Bool = false
    @State private var priority: Int = 0

    // Dates
    @State private var hasStartDate: Bool = false
    @State private var startDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasDoOnDate: Bool = false
    @State private var doOnDate: Date = Date()

    // Location
    @State private var hasDoAtLocation: Bool = false
    @State private var locationName: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""

    // Dependencies
    @State private var blockedByID: String = ""

    // Alerts
    @State private var showingError: Bool = false
    @State private var errorText: String = ""
    @State private var showingDeleteConfirmation: Bool = false

    // Calendar picker
    @State private var selectedCalendarID: String = ""

    var body: some View {
        Form {
            taskSection
            dateSection
            locationSection
            dependencySection
            notesSection
            infoSection

            if !isNew {
                deleteSection
            }
        }
        .navigationTitle(isNew ? "New Reminder" : "Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveChanges() }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorText)
        }
        .confirmationDialog("Delete Reminder?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteReminder() }
        }
        .onAppear { loadFromReminder() }
    }

    // MARK: - Sections

    private var taskSection: some View {
        Section("Task") {
            TextField("Title", text: $title)

            Toggle("Mark for Today", isOn: $markedToday)

            Picker("Priority", selection: $priority) {
                Text("None").tag(0)
                Text("Low").tag(9)
                Text("Medium").tag(5)
                Text("High").tag(1)
            }

            if isNew {
                Picker("List", selection: $selectedCalendarID) {
                    ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 8, height: 8)
                            Text(calendar.title)
                        }
                        .tag(calendar.calendarIdentifier)
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        Section("Dates") {
            Toggle("Start Date", isOn: $hasStartDate.animation())
            if hasStartDate {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
            }

            Toggle("Due Date", isOn: $hasDueDate.animation())
            if hasDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
            }

            Toggle("Do On Date", isOn: $hasDoOnDate.animation())
            if hasDoOnDate {
                DatePicker("Do On", selection: $doOnDate, displayedComponents: .date)
            }
        }
    }

    private var locationSection: some View {
        Section("Do At Location") {
            Toggle("Set Location", isOn: $hasDoAtLocation.animation())
            if hasDoAtLocation {
                TextField("Location Name (e.g., Home, Office)", text: $locationName)
                HStack {
                    TextField("Latitude", text: $latitude)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Longitude", text: $longitude)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
        }
    }

    private var dependencySection: some View {
        Section("Blocked By") {
            TextField("Blocking Task ID (paste from another task's Info section)", text: $blockedByID)
                .font(.caption)

            if !blockedByID.isEmpty {
                if let blocker = store.reminder(withExternalIdentifier: blockedByID) {
                    HStack {
                        Image(systemName: blocker.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(blocker.isCompleted ? .green : .orange)
                        Text(blocker.title ?? "Unknown Task")
                            .foregroundStyle(.secondary)
                        if blocker.isCompleted {
                            Text("(Completed)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("(Blocking)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("Task not found with this ID")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $userNotes)
                .frame(minHeight: 80)
        }
    }

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("List", value: reminder.calendar.title)

            if let attendees = reminder.attendees, !attendees.isEmpty {
                ForEach(Array(attendees.enumerated()), id: \.offset) { _, attendee in
                    LabeledContent(
                        attendee.isCurrentUser ? "Assigned to (You)" : "Assigned to",
                        value: attendee.name ?? "Unknown"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("External ID (for Blocked By)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(reminder.calendarItemExternalIdentifier ?? "Not available")
                    .font(.caption2)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Reminder", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    // MARK: - Load / Save

    private func loadFromReminder() {
        title = reminder.title ?? ""
        userNotes = store.userNotes(for: reminder)
        markedToday = store.metadata(for: reminder).markedToday == true
        priority = reminder.priority
        selectedCalendarID = reminder.calendar?.calendarIdentifier ?? ""

        if let start = reminder.startDateComponents?.toDate {
            hasStartDate = true
            startDate = start
        }
        if let due = reminder.dueDateComponents?.toDate {
            hasDueDate = true
            dueDate = due
        }

        let meta = store.metadata(for: reminder)
        if let doOn = meta.doOnDate {
            hasDoOnDate = true
            doOnDate = doOn
        }
        if let loc = meta.doAtLocation {
            hasDoAtLocation = true
            locationName = loc.name
            latitude = String(loc.latitude)
            longitude = String(loc.longitude)
        }
        blockedByID = meta.blockedBy ?? ""
    }

    private func saveChanges() {
        // Validate dates
        if let validationError = validateDates() {
            errorText = validationError
            showingError = true
            return
        }

        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorText = "Title cannot be empty."
            showingError = true
            return
        }

        reminder.title = title.trimmingCharacters(in: .whitespaces)
        // markedToday is saved in the metadata block below
        reminder.priority = priority

        // Calendar (only for new reminders)
        if isNew, !selectedCalendarID.isEmpty,
           let calendar = store.calendars.first(where: { $0.calendarIdentifier == selectedCalendarID }) {
            reminder.calendar = calendar
        }

        // Start Date
        if hasStartDate {
            var components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: startDate)
            components.calendar = Calendar(identifier: .gregorian)
            reminder.startDateComponents = components
        } else {
            reminder.startDateComponents = nil
        }

        // Due Date
        if hasDueDate {
            var dueComponents = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dueDate)
            dueComponents.calendar = Calendar(identifier: .gregorian)
            reminder.dueDateComponents = dueComponents

            // iOS requires start date if due date is set
            if !hasStartDate {
                var startComponents = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dueDate)
                startComponents.calendar = Calendar(identifier: .gregorian)
                reminder.startDateComponents = startComponents
            }
        } else {
            reminder.dueDateComponents = nil
        }

        // Build metadata
        var meta = TicklerMetadata()
        if hasDoOnDate {
            meta.doOnDate = doOnDate
        }
        if hasDoAtLocation,
           let lat = Double(latitude),
           let lon = Double(longitude),
           !locationName.trimmingCharacters(in: .whitespaces).isEmpty {
            meta.doAtLocation = TicklerLocation(
                name: locationName.trimmingCharacters(in: .whitespaces),
                latitude: lat,
                longitude: lon
            )
        }
        if !blockedByID.trimmingCharacters(in: .whitespaces).isEmpty {
            meta.blockedBy = blockedByID.trimmingCharacters(in: .whitespaces)
        }
        if markedToday {
            meta.markedToday = true
        }

        // Compose notes and save
        reminder.notes = TicklerMetadata.composedNotes(userNotes: userNotes, metadata: meta)

        do {
            try store.save(reminder)
            dismiss()
        } catch {
            errorText = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteReminder() {
        do {
            try store.delete(reminder)
            dismiss()
        } catch {
            errorText = "Failed to delete: \(error.localizedDescription)"
            showingError = true
        }
    }

    /// Validates date constraints: Start <= DoOn <= Due
    private func validateDates() -> String? {
        let cal = Calendar.current

        let effectiveStart = hasStartDate ? cal.startOfDay(for: startDate) : nil
        let effectiveDoOn = hasDoOnDate ? cal.startOfDay(for: doOnDate) : nil
        let effectiveDue = hasDueDate ? cal.startOfDay(for: dueDate) : nil

        if let start = effectiveStart, let doOn = effectiveDoOn, start > doOn {
            return "Start Date must be on or before the Do On Date."
        }

        if let start = effectiveStart, let due = effectiveDue, start > due {
            return "Start Date must be on or before the Due Date."
        }

        if let doOn = effectiveDoOn, let due = effectiveDue, doOn > due {
            return "Do On Date must be on or before the Due Date."
        }

        return nil
    }
}
