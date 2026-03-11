//
//  TicklerMetadata.swift
//  ToDo Tickler
//

import Foundation
import CoreLocation

// MARK: - TicklerLocation

struct TicklerLocation: Codable, Equatable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - TicklerMetadata

struct TicklerMetadata: Codable, Equatable, Sendable {
    var doOnDate: Date?
    var doAtLocation: TicklerLocation?
    var blockedBy: String? // calendarItemExternalIdentifier of blocking reminder
    var markedToday: Bool?

    static let startDelimiter = "--- ToDo Tickler Data (Do Not Edit Below This Line) ---"
    static let endDelimiter = "--- End ToDo Tickler Data ---"

    /// Whether this metadata has any meaningful values worth persisting.
    var isEmpty: Bool {
        doOnDate == nil && doAtLocation == nil && blockedBy == nil && markedToday != true
    }

    // MARK: - JSON Encoding/Decoding

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }

    // MARK: - Notes Parsing & Composition

    /// Extracts the user's own notes (everything above the metadata delimiter).
    static func userNotes(from rawNotes: String?) -> String {
        guard let rawNotes, !rawNotes.isEmpty else { return "" }

        if let delimiterRange = rawNotes.range(of: startDelimiter) {
            let userPortion = rawNotes[rawNotes.startIndex..<delimiterRange.lowerBound]
            return userPortion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return rawNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts TicklerMetadata from the JSON block in the notes field.
    /// Returns default (empty) metadata if no block is present or parsing fails.
    static func parse(from rawNotes: String?) -> TicklerMetadata {
        guard let rawNotes, !rawNotes.isEmpty else { return TicklerMetadata() }

        guard let startRange = rawNotes.range(of: startDelimiter),
              let endRange = rawNotes.range(of: endDelimiter) else {
            return TicklerMetadata()
        }

        let jsonStart = rawNotes.index(after: startRange.upperBound)
        guard jsonStart < endRange.lowerBound else { return TicklerMetadata() }

        let jsonString = rawNotes[jsonStart..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else { return TicklerMetadata() }

        do {
            return try decoder.decode(TicklerMetadata.self, from: jsonData)
        } catch {
            return TicklerMetadata()
        }
    }

    /// Composes a notes string from user notes and metadata.
    /// If metadata is empty, returns just the user notes (no metadata block).
    static func composedNotes(userNotes: String, metadata: TicklerMetadata) -> String {
        let trimmedNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !metadata.isEmpty else {
            return trimmedNotes
        }

        do {
            let jsonData = try encoder.encode(metadata)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            if trimmedNotes.isEmpty {
                return "\(startDelimiter)\n\(jsonString)\n\(endDelimiter)"
            } else {
                return "\(trimmedNotes)\n\n\(startDelimiter)\n\(jsonString)\n\(endDelimiter)"
            }
        } catch {
            return trimmedNotes
        }
    }
}

// MARK: - DateComponents Extension

extension DateComponents {
    /// Converts to a Date using the Gregorian calendar.
    var toDate: Date? {
        let gregorian = Calendar(identifier: .gregorian)
        return gregorian.date(from: self)
    }
}
