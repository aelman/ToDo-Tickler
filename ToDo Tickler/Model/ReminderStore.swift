//
//  ReminderStore.swift
//  ToDo Tickler
//

import EventKit
import Foundation
import Observation

@Observable
@MainActor
final class ReminderStore {

    // MARK: - Published State

    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    var reminders: [EKReminder] = []
    var calendars: [EKCalendar] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Private

    let eventStore = EKEventStore()
    private var notificationObserver: Any?

    // MARK: - Init

    init() {
        setupNotificationObserver()
    }

    // MARK: - Authorization

    func requestAccess() async {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        if currentStatus == .fullAccess {
            authorizationStatus = .fullAccess
            await fetchAllReminders()
            return
        }

        // Use the callback-based API wrapped in a continuation.
        // The async requestFullAccessToReminders() can hang on macOS.
        let store = eventStore
        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestFullAccessToReminders { granted, error in
                if let error {
                    print("Reminders access error: \(error)")
                }
                continuation.resume(returning: granted)
            }
        }

        let updatedStatus = EKEventStore.authorizationStatus(for: .reminder)
        authorizationStatus = updatedStatus
        if granted && updatedStatus == .fullAccess {
            await fetchAllReminders()
        }
    }

    // MARK: - Fetching

    func fetchAllReminders() async {
        isLoading = true
        defer { isLoading = false }

        calendars = eventStore.calendars(for: .reminder)

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let fetchedReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        reminders = fetchedReminders
    }

    // MARK: - Saving

    func save(_ reminder: EKReminder) throws {
        try eventStore.save(reminder, commit: true)
    }

    func toggleComplete(_ reminder: EKReminder) throws {
        reminder.isCompleted.toggle()
        try save(reminder)
    }

    func toggleToday(_ reminder: EKReminder) throws {
        var meta = metadata(for: reminder)
        let notes = userNotes(for: reminder)
        meta.markedToday = (meta.markedToday == true) ? nil : true
        try updateMetadata(for: reminder, metadata: meta, userNotes: notes)
    }

    func delete(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
    }

    // MARK: - Reminder Creation

    func createReminder(in calendar: EKCalendar? = nil) -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar ?? eventStore.defaultCalendarForNewReminders()
        return reminder
    }

    // MARK: - Metadata Helpers

    func metadata(for reminder: EKReminder) -> TicklerMetadata {
        TicklerMetadata.parse(from: reminder.notes)
    }

    func userNotes(for reminder: EKReminder) -> String {
        TicklerMetadata.userNotes(from: reminder.notes)
    }

    func updateMetadata(
        for reminder: EKReminder,
        metadata: TicklerMetadata,
        userNotes: String
    ) throws {
        reminder.notes = TicklerMetadata.composedNotes(
            userNotes: userNotes,
            metadata: metadata
        )
        try save(reminder)
    }

    // MARK: - Lookup

    func reminder(withIdentifier id: String) -> EKReminder? {
        eventStore.calendarItem(withIdentifier: id) as? EKReminder
    }

    func reminder(withExternalIdentifier id: String) -> EKReminder? {
        eventStore.calendarItems(withExternalIdentifier: id).first as? EKReminder
    }

    func reminders(in calendar: EKCalendar) -> [EKReminder] {
        reminders.filter { $0.calendar.calendarIdentifier == calendar.calendarIdentifier }
    }

    // MARK: - Filtered Views

    var todayReminders: [EKReminder] {
        let today = Calendar.current.startOfDay(for: Date())

        return reminders
            .filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard isAssignedToCurrentUserOrUnassigned(reminder) else { return false }

                // Condition 1: overdue (due date <= end of today)
                if let due = reminder.dueDateComponents?.toDate {
                    let dueDay = Calendar.current.startOfDay(for: due)
                    if dueDay <= today { return true }
                }

                // Condition 2: Do On Date <= today
                let meta = metadata(for: reminder)
                if let doOn = meta.doOnDate {
                    let doOnDay = Calendar.current.startOfDay(for: doOn)
                    if doOnDay <= today { return true }
                }

                // Condition 3: markedToday
                if meta.markedToday == true { return true }

                return false
            }
            .sorted { lhs, rhs in
                sortPriorityForToday(lhs) < sortPriorityForToday(rhs)
            }
    }

    var availableReminders: [EKReminder] {
        let today = Calendar.current.startOfDay(for: Date())

        return reminders
            .filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard isAssignedToCurrentUserOrUnassigned(reminder) else { return false }

                // Check start date: no start date, or start date <= today
                if let start = reminder.startDateComponents?.toDate {
                    let startDay = Calendar.current.startOfDay(for: start)
                    if startDay > today { return false }
                }

                // Check blocked-by: not blocked by an incomplete task
                let meta = metadata(for: reminder)
                if let blockerID = meta.blockedBy, !blockerID.isEmpty {
                    if let blocker = self.reminder(withExternalIdentifier: blockerID),
                       !blocker.isCompleted {
                        return false
                    }
                }

                return true
            }
            .sorted { lhs, rhs in
                // Sort by priority (lower number = higher priority), then by title
                if lhs.priority != rhs.priority {
                    if lhs.priority == 0 { return false } // no priority sorts last
                    if rhs.priority == 0 { return true }
                    return lhs.priority < rhs.priority
                }
                return (lhs.title ?? "") < (rhs.title ?? "")
            }
    }

    var upcomingReminders: [EKReminder] {
        let today = Calendar.current.startOfDay(for: Date())

        return reminders
            .filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard isAssignedToCurrentUserOrUnassigned(reminder) else { return false }

                // Include if start date is after today
                if let start = reminder.startDateComponents?.toDate {
                    let startDay = Calendar.current.startOfDay(for: start)
                    if startDay > today { return true }
                }

                // Include if do-on date is after today
                let meta = metadata(for: reminder)
                if let doOn = meta.doOnDate {
                    let doOnDay = Calendar.current.startOfDay(for: doOn)
                    if doOnDay > today { return true }
                }

                return false
            }
            .sorted { lhs, rhs in
                // Sort by earliest upcoming date
                let lhsDate = earliestUpcomingDate(for: lhs)
                let rhsDate = earliestUpcomingDate(for: rhs)
                return lhsDate < rhsDate
            }
    }

    // MARK: - Private Helpers

    private func earliestUpcomingDate(for reminder: EKReminder) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        let farFuture = Date.distantFuture
        let meta = metadata(for: reminder)

        var earliest = farFuture
        if let start = reminder.startDateComponents?.toDate {
            let startDay = Calendar.current.startOfDay(for: start)
            if startDay > today { earliest = min(earliest, startDay) }
        }
        if let doOn = meta.doOnDate {
            let doOnDay = Calendar.current.startOfDay(for: doOn)
            if doOnDay > today { earliest = min(earliest, doOnDay) }
        }
        return earliest
    }

    private func isAssignedToCurrentUserOrUnassigned(_ reminder: EKReminder) -> Bool {
        guard let attendees = reminder.attendees, !attendees.isEmpty else {
            return true
        }
        return attendees.contains { $0.isCurrentUser }
    }

    private func sortPriorityForToday(_ reminder: EKReminder) -> Int {
        // Overdue items first (0), then Do On Date items (1), then flagged (2)
        let today = Calendar.current.startOfDay(for: Date())

        if let due = reminder.dueDateComponents?.toDate {
            let dueDay = Calendar.current.startOfDay(for: due)
            if dueDay <= today { return 0 }
        }

        let meta = metadata(for: reminder)
        if let doOn = meta.doOnDate {
            let doOnDay = Calendar.current.startOfDay(for: doOn)
            if doOnDay <= today { return 1 }
        }

        return 2 // flagged
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAllReminders()
            }
        }
    }
}
