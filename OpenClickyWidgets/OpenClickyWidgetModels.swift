import Foundation

struct OpenClickyWidgetSnapshot: Codable, Equatable {
    static let schemaVersion = 1

    var schemaVersion: Int
    var generatedAt: Date
    var activeAgents: [OpenClickyWidgetAgentSummary]
    var todayStats: OpenClickyWidgetTodayStats
    var needsAttention: [OpenClickyWidgetAttentionItem]
    var latestMemorySummary: String?
    var privacy: OpenClickyWidgetPrivacySettings

    static let empty = OpenClickyWidgetSnapshot(
        schemaVersion: schemaVersion,
        generatedAt: Date(),
        activeAgents: [],
        todayStats: OpenClickyWidgetTodayStats(),
        needsAttention: [],
        latestMemorySummary: nil,
        privacy: OpenClickyWidgetPrivacySettings()
    )
}

struct OpenClickyWidgetAgentSummary: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var status: String
    var caption: String?
    var updatedAt: Date
}

struct OpenClickyWidgetTodayStats: Codable, Equatable {
    var voiceInteractions: Int
    var agentTasksCreated: Int
    var agentCompletions: Int
    var agentFailures: Int
    var logReviewComments: Int

    init(
        voiceInteractions: Int = 0,
        agentTasksCreated: Int = 0,
        agentCompletions: Int = 0,
        agentFailures: Int = 0,
        logReviewComments: Int = 0
    ) {
        self.voiceInteractions = voiceInteractions
        self.agentTasksCreated = agentTasksCreated
        self.agentCompletions = agentCompletions
        self.agentFailures = agentFailures
        self.logReviewComments = logReviewComments
    }
}

struct OpenClickyWidgetAttentionItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, Equatable {
        case failedAgent
        case missingPermission
        case missingCredential
        case flaggedLog
        case staleSnapshot
    }

    var id: UUID
    var kind: Kind
    var title: String
    var detail: String?
    var createdAt: Date
    var deepLink: URL?
}

struct OpenClickyWidgetPrivacySettings: Codable, Equatable {
    var widgetsEnabled: Bool
    var includesAgentTaskNames: Bool
    var includesMemorySnippets: Bool
    var includesFocusedAppContext: Bool

    init(
        widgetsEnabled: Bool = true,
        includesAgentTaskNames: Bool = false,
        includesMemorySnippets: Bool = false,
        includesFocusedAppContext: Bool = false
    ) {
        self.widgetsEnabled = widgetsEnabled
        self.includesAgentTaskNames = includesAgentTaskNames
        self.includesMemorySnippets = includesMemorySnippets
        self.includesFocusedAppContext = includesFocusedAppContext
    }
}

enum OpenClickyWidgetDeepLink {
    static let agents = URL(string: "openclicky://agents")!
    static let settings = URL(string: "openclicky://settings")!
    static let logs = URL(string: "openclicky://logs")!
    static let memory = URL(string: "openclicky://memory")!
}
