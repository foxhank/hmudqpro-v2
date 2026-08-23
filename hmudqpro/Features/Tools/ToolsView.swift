import SwiftUI

/// 工具页：对齐安卓端四大分组（信息查询/便捷功能/业务办理/快捷跳转）。
/// 已移植的功能 NavigationLink 进入，未移植的进入占位页标注状态。
struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                ToolSection(titleKey: "tools.group.query") {
                    ToolRow(icon: "doc.text.fill", tint: .blue, titleKey: "tool.grades", subtitleKey: "tool.grades.sub") {
                        GradesView()
                    }
                    ToolRow(icon: "graduationcap.fill", tint: .orange, titleKey: "tool.examGrades", subtitleKey: "tool.examGrades.sub", isLab: true) {
                        ExamGradesView()
                    }
                    ToolRow(icon: "clock.fill", tint: .green, titleKey: "tool.examInfo", subtitleKey: "tool.examInfo.sub", isLab: true) {
                        ComingSoonView(titleKey: "tool.examInfo")
                    }
                    ToolRow(icon: "door.left.hand.open", tint: .gray, titleKey: "tool.emptyClassroom", subtitleKey: "tool.emptyClassroom.sub") {
                        ComingSoonView(titleKey: "tool.emptyClassroom")
                    }
                }
                ToolSection(titleKey: "tools.group.convenience") {
                    ToolLink(icon: "wrench.and.screwdriver.fill", tint: .orange, titleKey: "tool.dormRepair", subtitleKey: "tool.dormRepair.sub", url: APIConfig.mikecrmRepair)
                    ToolLink(icon: "book.fill", tint: .blue, titleKey: "tool.ebook", subtitleKey: "tool.ebook.sub", url: APIConfig.ebookURL)
                }
                ToolSection(titleKey: "tools.group.business") {
                    ToolRow(icon: "square.grid.2x2", tint: .blue, titleKey: "tool.courseSelect", subtitleKey: "tool.courseSelect.sub") {
                        ComingSoonView(titleKey: "tool.courseSelect")
                    }
                    ToolRow(icon: "person.text.rectangle.fill", tint: .purple, titleKey: "tool.evaluation", subtitleKey: "tool.evaluation.sub") {
                        ComingSoonView(titleKey: "tool.evaluation")
                    }
                }
                ToolSection(titleKey: "tools.group.links") {
                    ToolLink(icon: "building.columns.fill", tint: .blue, titleKey: "tool.academicSystem", subtitleKey: "tool.academicSystem.sub", url: APIConfig.jwcDesktopURL)
                    ToolLink(icon: "globe.asia.australia.fill", tint: .green, titleKey: "tool.schoolPortal", subtitleKey: "tool.schoolPortal.sub", url: APIConfig.schoolHome)
                    ToolLink(icon: "books.vertical.fill", tint: .blue, titleKey: "tool.cnki", subtitleKey: "tool.cnki.sub", url: APIConfig.cnkiWebvpn)
                    ToolLink(icon: "books.vertical", tint: .orange, titleKey: "tool.wanfang", subtitleKey: "tool.wanfang.sub", url: APIConfig.wanfangWebvpn)
                }
            }
            .navigationTitle(String(localized: "tab.tools"))
        }
    }
}

private struct ToolSection<Content: View>: View {
    let titleKey: String
    @ViewBuilder var content: Content

    var body: some View {
        Section(NSLocalizedString(titleKey, comment: "")) {
            content
        }
    }
}

private struct ToolRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String?
    var isLab = false
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            ToolLabel(icon: icon, tint: tint, titleKey: titleKey, subtitleKey: subtitleKey, isLab: isLab)
        }
    }
}

/// 外链：SFSafariViewController 风格（Safari 打开，免自建 WebView）。
private struct ToolLink: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            ToolLabel(icon: icon, tint: tint, titleKey: titleKey, subtitleKey: subtitleKey, isLab: false)
        }
    }
}

private struct ToolLabel: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String?
    let isLab: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(NSLocalizedString(titleKey, comment: ""))
                        .foregroundStyle(.primary)
                    if isLab {
                        Text(String(localized: "tool.labBadge"))
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                if let sub = subtitleKey {
                    Text(NSLocalizedString(sub, comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 未移植功能占位页。
struct ComingSoonView: View {
    let titleKey: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "tool.comingSoon"))
                .foregroundStyle(.secondary)
        }
        .navigationTitle(NSLocalizedString(titleKey, comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ToolsView()
}
