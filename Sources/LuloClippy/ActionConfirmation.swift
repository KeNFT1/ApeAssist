import Foundation
import SwiftUI

/// Classes of user-visible risk that require explicit human approval before Lulo/OpenClaw proceeds.
enum ActionRisk: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case externalSend
    case browserOrAppClick
    case fileDeletion
    case tradingOrFinancial
    case configChange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .externalSend: "External send"
        case .browserOrAppClick: "Browser/app click"
        case .fileDeletion: "File deletion"
        case .tradingOrFinancial: "Trading/financial action"
        case .configChange: "Configuration change"
        }
    }

    var systemImage: String {
        switch self {
        case .externalSend: "paperplane.fill"
        case .browserOrAppClick: "cursorarrow.click.2"
        case .fileDeletion: "trash.fill"
        case .tradingOrFinancial: "dollarsign.circle.fill"
        case .configChange: "gearshape.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .externalSend: .blue
        case .browserOrAppClick: .orange
        case .fileDeletion: .red
        case .tradingOrFinancial: .green
        case .configChange: .purple
        }
    }

    var policySummary: String {
        switch self {
        case .externalSend:
            "Anything that sends, posts, emails, texts, uploads, or publishes outside this Mac."
        case .browserOrAppClick:
            "Clicks, form submissions, app automation, or UI actions that could change remote or local state."
        case .fileDeletion:
            "Deletes, trashing, overwrites, bulk moves, or other potentially destructive file operations."
        case .tradingOrFinancial:
            "Trades, orders, withdrawals, payments, subscriptions, purchases, or spending money."
        case .configChange:
            "Gateway, app, security, credential, cron, or automation configuration changes."
        }
    }
}

enum PendingActionStatus: String, Codable, Equatable, Sendable {
    case pending
    case approved
    case denied

    var label: String {
        switch self {
        case .pending: "Awaiting approval"
        case .approved: "Approved"
        case .denied: "Denied"
        }
    }
}

/// A local UI representation of an OpenClaw/tool action proposal.
///
/// The Gateway wire protocol is intentionally not assumed yet. For now this carries enough
/// inspectable detail for the user to approve/deny, and can later be mapped to Gateway approval IDs.
struct PendingAction: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let risk: ActionRisk
    let title: String
    let summary: String
    let details: [ActionDetail]
    let gatewayApprovalID: String?
    var status: PendingActionStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        risk: ActionRisk,
        title: String,
        summary: String,
        details: [ActionDetail] = [],
        gatewayApprovalID: String? = nil,
        status: PendingActionStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.risk = risk
        self.title = title
        self.summary = summary
        self.details = details
        self.gatewayApprovalID = gatewayApprovalID
        self.status = status
        self.createdAt = createdAt
    }
}

struct ActionDetail: Codable, Equatable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

extension PendingAction {
    /// Local-only placeholder detector used until OpenClaw streams native approval proposals.
    /// This is deliberately narrow: it should only show the confirmation UX for clear,
    /// executable risky intents and never for ordinary setup/config discussion.
    static func placeholderProposal(for text: String) -> PendingAction? {
        guard let risk = RiskIntentDetector.detect(in: text) else {
            return nil
        }

        return PendingAction(
            risk: risk,
            title: "Confirm before: \(risk.title)",
            summary: "Lulo detected that this request may require a risky action. This placeholder card proves the approval path before any Gateway execution is wired.",
            details: [
                ActionDetail(label: "Requested text", value: String(text.prefix(500))),
                ActionDetail(label: "Policy", value: risk.policySummary),
                ActionDetail(label: "Execution", value: "Stub only — approve/deny records intent but does not perform the action yet.")
            ]
        )
    }
}

enum RiskIntentDetector {
    private static let configObjects = ["config", "configuration", "setting", "settings", "credential", "credentials", "token", "api key", "cron", "gateway", "endpoint", "post mode", "automation"]
    private static let configVerbs = ["apply", "change", "update", "set", "edit", "enable", "disable", "restart", "rotate", "delete", "remove", "store", "save", "configure"]
    private static let financialVerbs = ["buy", "sell", "trade", "order", "withdraw", "pay", "purchase", "spend", "subscribe"]
    private static let externalSendVerbs = ["send", "post", "tweet", "publish", "upload", "share"]
    private static let directCommunicationVerbs = ["email", "text", "sms", "message"]
    private static let fileVerbs = ["delete", "remove", "trash", "wipe", "overwrite", "rm"]
    private static let browserVerbs = ["click", "submit", "press", "fill"]
    private static let browserObjects = ["button", "form", "browser", "app", "page", "website"]

    static func detect(in text: String) -> ActionRisk? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }
        guard !startsWithInformationQuestion(normalized) else { return nil }

        if containsAny(normalized, financialVerbs) {
            return .tradingOrFinancial
        }

        if containsAny(normalized, externalSendVerbs) || startsWithCommandVerb(normalized, directCommunicationVerbs) {
            return .externalSend
        }

        if containsAny(normalized, fileVerbs), containsLikelyFileTarget(normalized) {
            return .fileDeletion
        }

        if containsAny(normalized, configVerbs), containsAny(normalized, configObjects) {
            return .configChange
        }

        if containsAny(normalized, browserVerbs), containsAny(normalized, browserObjects) {
            return .browserOrAppClick
        }

        return nil
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_./-]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { containsTerm($0, in: text) }
    }

    private static func containsTerm(_ term: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        return text.range(of: #"(^|\s)\#(escaped)(\s|$)"#, options: .regularExpression) != nil
    }

    private static func containsLikelyFileTarget(_ text: String) -> Bool {
        containsAny(text, ["file", "files", "folder", "folders", "directory", "directories", "path", "paths"])
            || text.contains("/")
            || text.range(of: #"\.[a-z0-9]{1,8}(\s|$)"#, options: .regularExpression) != nil
    }

    private static func startsWithCommandVerb(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { term in
            containsTerm(term, in: text)
                && (text.hasPrefix(term + " ")
                    || text.hasPrefix("please " + term + " ")
                    || text.hasPrefix("can you " + term + " ")
                    || text.hasPrefix("could you " + term + " "))
        }
    }

    private static func startsWithInformationQuestion(_ text: String) -> Bool {
        ["what ", "where ", "why ", "who ", "when ", "how "].contains { text.hasPrefix($0) }
    }
}
