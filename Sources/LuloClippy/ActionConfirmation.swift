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
    /// This is deliberately conservative: it shows the confirmation UX and does not execute anything.
    static func placeholderProposal(for text: String) -> PendingAction? {
        let lowercased = text.lowercased()

        let keywordMap: [(ActionRisk, [String])] = [
            (.tradingOrFinancial, ["trade", "buy ", "sell ", "order", "withdraw", "payment", "pay ", "purchase", "spend", "subscription", "usdc", "crypto"]),
            (.fileDeletion, ["delete", "remove file", "trash", "wipe", "overwrite", "rm "]),
            (.externalSend, ["send email", "email ", "text ", "sms", "message ", "post ", "tweet", "publish", "upload", "share "]),
            (.configChange, ["config", "settings", "credential", "token", "api key", "cron", "gateway", "restart", "enable post"]),
            (.browserOrAppClick, ["click", "submit", "press button", "fill form", "browser", "app automation"])
        ]

        guard let match = keywordMap.first(where: { _, keywords in keywords.contains { lowercased.contains($0) } }) else {
            return nil
        }

        return PendingAction(
            risk: match.0,
            title: "Confirm before: \(match.0.title)",
            summary: "Lulo detected that this request may require a risky action. This placeholder card proves the approval path before any Gateway execution is wired.",
            details: [
                ActionDetail(label: "Requested text", value: String(text.prefix(500))),
                ActionDetail(label: "Policy", value: match.0.policySummary),
                ActionDetail(label: "Execution", value: "Stub only — approve/deny records intent but does not perform the action yet.")
            ]
        )
    }
}
