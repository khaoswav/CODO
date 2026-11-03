import SwiftUI

struct AIChangeReviewView: View {
    let project: CODOProject
    let root: URL
    @State var changes: [ProjectFileChange]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedForApply: ProjectFileChange?
    @State private var errorMessage: String?
    @State private var rejectedCount = 0
    @State private var appliedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(CODOTheme.border)
            if changes.isEmpty {
                ContentUnavailableView(
                    "Review complete",
                    systemImage: "checkmark.seal",
                    description: Text("\(appliedCount) applied · \(rejectedCount) rejected")
                )
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(changes) { change in changeCard(change) }
                    }
                    .padding(18)
                }
            }
            footer
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(CODOTheme.background)
        .confirmationDialog(
            "Apply this file change?",
            isPresented: Binding(
                get: { selectedForApply != nil },
                set: { if !$0 { selectedForApply = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Create backup and apply", role: .destructive) {
                if let change = selectedForApply { apply(change) }
                selectedForApply = nil
            }
            Button("Cancel", role: .cancel) { selectedForApply = nil }
        } message: {
            Text("CODO will re-check the original file, create a backup, then write the approved content. This approval applies only to the selected file.")
        }
        .alert("Could not apply change", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CODOTheme.accent)
                .frame(width: 40, height: 40)
                .background(CODOTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("Review AI Changes").font(.system(size: 18, weight: .semibold))
                Text("\(project.name) · \(changes.count) file(s) awaiting review")
                    .font(.system(size: 11)).foregroundStyle(CODOTheme.secondaryText)
            }
            Spacer()
            Label("Nothing is applied automatically", systemImage: "lock.shield")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CODOTheme.green)
        }
        .padding(18)
    }

    private func changeCard(_ change: ProjectFileChange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text").foregroundStyle(CODOTheme.accent)
                Text(change.relativePath).font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer()
                Text("MODIFIED").font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(CODOTheme.orange)
            }

            HStack(spacing: 0) {
                diffColumn(title: "ORIGINAL", text: change.originalText, tint: CODOTheme.red)
                Rectangle().fill(CODOTheme.border).frame(width: 1)
                diffColumn(title: "PROPOSED", text: change.proposedText, tint: CODOTheme.green)
            }
            .frame(height: 230)
            .background(CODOTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            HStack {
                Button("Reject") {
                    changes.removeAll { $0.id == change.id }
                    rejectedCount += 1
                }
                .buttonStyle(.bordered)
                Spacer()
                Button {
                    selectedForApply = change
                } label: {
                    Label("Approve & Apply", systemImage: "checkmark")
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(14)
        .background(CODOTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CODOTheme.border, lineWidth: 1))
    }

    private func diffColumn(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.system(size: 9, weight: .bold)).tracking(0.8)
                Spacer()
                Text("\(text.components(separatedBy: .newlines).count) lines")
                    .font(.system(size: 9, design: .monospaced))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 8)
            Divider().overlay(CODOTheme.border)
            ScrollView([.vertical, .horizontal]) {
                let lines = text.components(separatedBy: .newlines)
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(String(index + 1))
                                .foregroundStyle(CODOTheme.mutedText)
                                .frame(width: 34, alignment: .trailing)
                            Text(line.isEmpty ? " " : line)
                                .foregroundStyle(CODOTheme.primaryText)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 8)
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 7)
                        .background(tint.opacity(0.055))
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text("\(appliedCount) applied · \(rejectedCount) rejected · \(changes.count) pending")
                .font(.system(size: 10)).foregroundStyle(CODOTheme.secondaryText)
            Spacer()
            Button("Close") { dismiss() }.buttonStyle(.bordered)
                .disabled(!changes.isEmpty)
        }
        .padding(16)
        .background(CODOTheme.elevated.opacity(0.6))
    }

    private func apply(_ change: ProjectFileChange) {
        do {
            try ProjectFileChangeService.apply(change, project: project, root: root, approved: true)
            changes.removeAll { $0.id == change.id }
            appliedCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
