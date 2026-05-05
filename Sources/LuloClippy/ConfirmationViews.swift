import SwiftUI

struct PendingActionCard: View {
    let action: PendingAction
    let onReview: () -> Void
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: action.risk.systemImage)
                    .foregroundStyle(action.risk.tint)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                    Text(action.risk.title)
                        .font(.caption.bold())
                        .foregroundStyle(action.risk.tint)
                    Text(action.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(action.status.label)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBackground)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Button("Review details", action: onReview)
                Spacer()
                Button("Deny", role: .cancel, action: onDeny)
                    .disabled(action.status != .pending)
                Button("Approve once", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .disabled(action.status != .pending)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(action.risk.tint.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(action.risk.tint.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusBackground: Color {
        switch action.status {
        case .pending: action.risk.tint.opacity(0.18)
        case .approved: Color.green.opacity(0.18)
        case .denied: Color.red.opacity(0.18)
        }
    }
}

struct ConfirmationSheet: View {
    let action: PendingAction
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: action.risk.systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(action.risk.tint)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm risky action")
                        .font(.title2.bold())
                    Text(action.title)
                        .font(.headline)
                    Text(action.risk.policySummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Action summary")
                    .font(.headline)
                Text(action.summary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !action.details.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.headline)
                    ForEach(action.details) { detail in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detail.label)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(detail.value)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if let gatewayApprovalID = action.gatewayApprovalID {
                LabeledContent("Gateway approval ID", value: gatewayApprovalID)
                    .font(.caption)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button("Close", action: onDismiss)
                Spacer()
                Button("Deny", role: .destructive, action: onDeny)
                    .disabled(action.status != .pending)
                Button("Approve once", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .disabled(action.status != .pending)
            }
        }
        .padding(24)
        .frame(width: 520)
        .frame(minHeight: 460)
    }
}
