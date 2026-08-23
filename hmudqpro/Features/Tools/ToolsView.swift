import SwiftUI

/// 工具页：标准列表布局，分组对齐安卓端（考试信息已废弃移除）。
struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "tools.group.query")) {
                    NavigationLink { GradesView() } label: {
                        ToolLabel(icon: "doc.text.fill", tint: .blue,
                                  titleKey: "tool.grades", subtitleKey: "tool.grades.sub")
                    }
                    NavigationLink { ExamGradesView() } label: {
                        ToolLabel(icon: "graduationcap.fill", tint: .orange,
                                  titleKey: "tool.examGrades", subtitleKey: "tool.examGrades.sub")
                    }
                    NavigationLink { ComingSoonView(titleKey: "tool.emptyClassroom") } label: {
                        ToolLabel(icon: "door.left.hand.open", tint: .gray,
                                  titleKey: "tool.emptyClassroom", subtitleKey: "tool.emptyClassroom.sub")
                    }
                }
                Section(String(localized: "tools.group.convenience")) {
                    Link(destination: APIConfig.mikecrmRepair) {
                        ToolLabel(icon: "wrench.and.screwdriver.fill", tint: .orange,
                                  titleKey: "tool.dormRepair", subtitleKey: "tool.dormRepair.sub")
                    }
                    Link(destination: APIConfig.ebookURL) {
                        ToolLabel(icon: "book.fill", tint: .blue,
                                  titleKey: "tool.ebook", subtitleKey: "tool.ebook.sub")
                    }
                }
                Section(String(localized: "tools.group.business")) {
                    NavigationLink { ComingSoonView(titleKey: "tool.courseSelect") } label: {
                        ToolLabel(icon: "square.grid.2x2", tint: .blue,
                                  titleKey: "tool.courseSelect", subtitleKey: "tool.courseSelect.sub")
                    }
                    NavigationLink { ComingSoonView(titleKey: "tool.evaluation") } label: {
                        ToolLabel(icon: "person.text.rectangle.fill", tint: .purple,
                                  titleKey: "tool.evaluation", subtitleKey: "tool.evaluation.sub")
                    }
                }
                Section(String(localized: "tools.group.links")) {
                    Link(destination: APIConfig.jwcDesktopURL) {
                        ToolLabel(icon: "building.columns.fill", tint: .blue,
                                  titleKey: "tool.academicSystem", subtitleKey: "tool.academicSystem.sub")
                    }
                    Link(destination: APIConfig.schoolHome) {
                        ToolLabel(icon: "globe.asia.australia.fill", tint: .green,
                                  titleKey: "tool.schoolPortal", subtitleKey: "tool.schoolPortal.sub")
                    }
                    Link(destination: APIConfig.cnkiWebvpn) {
                        ToolLabel(icon: "books.vertical.fill", tint: .blue,
                                  titleKey: "tool.cnki", subtitleKey: "tool.cnki.sub")
                    }
                    Link(destination: APIConfig.wanfangWebvpn) {
                        ToolLabel(icon: "books.vertical", tint: .orange,
                                  titleKey: "tool.wanfang", subtitleKey: "tool.wanfang.sub")
                    }
                }
            }
            .navigationTitle(String(localized: "tab.tools"))
        }
    }
}

/// 列表行：图标 + 标题 + 副标题。
private struct ToolLabel: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString(titleKey, comment: ""))
                Text(NSLocalizedString(subtitleKey, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
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
