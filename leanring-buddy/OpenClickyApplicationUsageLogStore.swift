import AppKit
import Foundation

nonisolated final class OpenClickyApplicationUsageLogStore: @unchecked Sendable {
    static let shared = OpenClickyApplicationUsageLogStore()

    private struct UsageFile: Codable {
        var updatedAt: String
        var applications: [ApplicationEntry]
    }

    private struct ApplicationEntry: Codable {
        var name: String
        var bundleIdentifier: String?
        var firstSeenAt: String
        var lastSeenAt: String
        var seenCount: Int
        var sources: [String]
    }

    private let fileManager: FileManager
    private let lock = NSLock()

    let logURL: URL

    init(fileManager: FileManager = .default, logURL: URL? = nil) {
        self.fileManager = fileManager
        self.logURL = logURL ?? Self.defaultLogURL(fileManager: fileManager)
    }

    func recordFrontmostApplication(source: String) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        recordApplication(
            name: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            source: source
        )
    }

    func recordApplication(name: String?, bundleIdentifier: String?, source: String) {
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty || !(trimmedBundleIdentifier?.isEmpty ?? true) else { return }

        let wasNew = updateUsageFile(
            name: trimmedName.isEmpty ? trimmedBundleIdentifier ?? "Unknown app" : trimmedName,
            bundleIdentifier: (trimmedBundleIdentifier?.isEmpty == false) ? trimmedBundleIdentifier : nil,
            source: source
        )

        guard wasNew else { return }
        OpenClickyMessageLogStore.shared.append(
            lane: "app-usage",
            direction: "internal",
            event: "openclicky.application_usage.discovered",
            fields: [
                "name": trimmedName,
                "bundleIdentifier": trimmedBundleIdentifier ?? "",
                "source": source,
                "logPath": logURL.path
            ]
        )
    }

    private func updateUsageFile(name: String, bundleIdentifier: String?, source: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let now = isoTimestamp()
            var usage = readUsageFile(updatedAt: now)
            let key = entryKey(name: name, bundleIdentifier: bundleIdentifier)

            if let index = usage.applications.firstIndex(where: {
                entryKey(name: $0.name, bundleIdentifier: $0.bundleIdentifier) == key
            }) {
                usage.applications[index].name = name
                usage.applications[index].bundleIdentifier = bundleIdentifier ?? usage.applications[index].bundleIdentifier
                usage.applications[index].lastSeenAt = now
                usage.applications[index].seenCount += 1
                if !usage.applications[index].sources.contains(source) {
                    usage.applications[index].sources.append(source)
                    usage.applications[index].sources.sort()
                }
                usage.updatedAt = now
                try write(usage)
                return false
            }

            usage.applications.append(ApplicationEntry(
                name: name,
                bundleIdentifier: bundleIdentifier,
                firstSeenAt: now,
                lastSeenAt: now,
                seenCount: 1,
                sources: [source]
            ))
            usage.applications.sort { first, second in
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
            usage.updatedAt = now
            try write(usage)
            return true
        } catch {
            print("OpenClicky application usage log write failed: \(error.localizedDescription)")
            return false
        }
    }

    private func readUsageFile(updatedAt: String) -> UsageFile {
        guard let data = try? Data(contentsOf: logURL),
              let decoded = try? JSONDecoder().decode(UsageFile.self, from: data) else {
            return UsageFile(updatedAt: updatedAt, applications: [])
        }
        return decoded
    }

    private func write(_ usage: UsageFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(usage)
        try data.write(to: logURL, options: [.atomic])
    }

    private func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }

    private func entryKey(name: String, bundleIdentifier: String?) -> String {
        if let bundleIdentifier,
           !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        let normalizedName = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "name:\(normalizedName)"
    }

    private static func defaultLogURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("OpenClicky", isDirectory: true)
            .appendingPathComponent("app-usage.json", isDirectory: false)
    }
}
