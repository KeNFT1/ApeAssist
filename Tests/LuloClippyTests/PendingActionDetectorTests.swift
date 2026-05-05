import Testing
@testable import LuloClippy

@Suite("Pending action placeholder detector")
struct PendingActionDetectorTests {
    @Test func ordinarySetupAndExplanationsDoNotNeedApproval() {
        let safeTexts = [
            "where are settings",
            "what is my gateway endpoint",
            "token stored in keychain"
        ]

        for text in safeTexts {
            #expect(PendingAction.placeholderProposal(for: text) == nil, "Unexpected approval for: \(text)")
        }
    }

    @Test func clearRiskyActionIntentsNeedApproval() throws {
        let cases: [(String, ActionRisk)] = [
            ("send email", .externalSend),
            ("delete file", .fileDeletion),
            ("buy crypto", .tradingOrFinancial),
            ("restart gateway", .configChange),
            ("apply config change", .configChange)
        ]

        for (text, expectedRisk) in cases {
            let proposal = try #require(PendingAction.placeholderProposal(for: text), "Missing approval for: \(text)")
            #expect(proposal.risk == expectedRisk)
            #expect(proposal.status == .pending)
        }
    }
}
