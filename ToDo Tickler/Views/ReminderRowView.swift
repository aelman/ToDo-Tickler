//
//  ReminderRowView.swift
//  ToDo Tickler
//

import EventKit
import SwiftUI

struct ReminderRowView: View {
    let reminder: EKReminder
    let isNearLocation: Bool
    var onToggleComplete: () -> Void

    @Environment(ReminderStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            // Completion circle
            Button(action: onToggleComplete) {
                Image(systemName: reminder.isCompleted ? "circle.inset.filled" : "circle")
                    .font(.title3)
                    .foregroundStyle(calendarColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title ?? "Untitled")
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                subtitleView
            }

            Spacer()

            trailingIcons
        }
        .padding(.vertical, 2)
        .listRowBackground(isNearLocation ? Color.blue.opacity(0.08) : nil)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var subtitleView: some View {
        let meta = store.metadata(for: reminder)
        let hasSubtitle = reminder.dueDateComponents?.toDate != nil
            || reminder.startDateComponents?.toDate != nil
            || meta.doOnDate != nil
            || meta.blockedBy != nil

        if hasSubtitle {
            HStack(spacing: 6) {
                if let start = reminder.startDateComponents?.toDate {
                    Label(start.formatted(.dateTime.month(.abbreviated).day()), systemImage: "arrow.right")
                        .foregroundStyle(.secondary)
                }

                if let doOn = meta.doOnDate {
                    let doOnDay = Calendar.current.startOfDay(for: doOn)
                    let today = Calendar.current.startOfDay(for: Date())
                    Label(doOn.formatted(.dateTime.month(.abbreviated).day()), systemImage: "arrow.right.circle")
                        .foregroundStyle(doOnDay <= today ? .blue : .secondary)
                }

                if let due = reminder.dueDateComponents?.toDate {
                    let dueDay = Calendar.current.startOfDay(for: due)
                    let today = Calendar.current.startOfDay(for: Date())
                    let color: Color = dueDay < today ? .red : dueDay == today ? .green : .secondary
                    Label(due.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                        .foregroundStyle(color)
                }

                if meta.blockedBy != nil {
                    Label("Blocked", systemImage: "link")
                        .foregroundStyle(.orange)
                }

                Text(reminder.calendar.title)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var trailingIcons: some View {
        HStack(spacing: 6) {
            let meta = store.metadata(for: reminder)
            if meta.markedToday == true {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            if meta.doAtLocation != nil {
                Image(systemName: isNearLocation ? "location.fill" : "location")
                    .foregroundStyle(isNearLocation ? .blue : .secondary)
                    .font(.caption)
            }
        }
    }

    private var calendarColor: Color {
        Color(cgColor: reminder.calendar.cgColor)
    }
}
