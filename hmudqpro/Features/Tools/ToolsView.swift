import SwiftUI

/// 工具页：网格布局（对齐安卓 2.0 图标卡片）+ 赞助开发者单独一行。
/// 快捷跳转走内置 WebView（Cookie 自动登录），不再跳系统浏览器。
struct ToolsView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
    private let pink = Color.pink

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                    toolSection("tools.group.query") {
                        ToolCard(icon: "doc.text.fill", tint: .blue, titleKey: "tool.grades") { GradesView() }
                        ToolCard(icon: "graduationcap.fill", tint: .orange, titleKey: "tool.examGrades") { ExamGradesView() }
                        ToolCard(icon: "door.left.hand.open", tint: .gray, titleKey: "tool.emptyClassroom") { EmptyClassroomView() }
                    }
                    toolSection("tools.group.business") {
                        ToolCard(icon: "square.grid.2x2", tint: .blue, titleKey: "tool.courseSelect") { CourseSelectionScreen() }
                        ToolCard(icon: "person.text.rectangle.fill", tint: .purple, titleKey: "tool.evaluation") { EvaluationView() }
                        ToolCard(icon: "wrench.and.screwdriver.fill", tint: .orange, titleKey: "tool.dormRepair") {
                            WebViewScreen(titleKey: "tool.dormRepair", url: APIConfig.mikecrmRepair)
                        }
                    }
                    toolSection("tools.group.convenience") {
                        ToolCard(icon: "book.fill", tint: .blue, titleKey: "tool.ebook") {
                            WebViewScreen(titleKey: "tool.ebook", url: APIConfig.ebookURL)
                        }
                        ToolCard(icon: "square.stack.3d.up.fill", tint: .purple, titleKey: "tool.shuati") {
                            WebViewScreen(titleKey: "tool.shuati", url: APIConfig.shuatiURL)
                        }
                    }
                    toolSection("tools.group.links") {
                        ToolCard(icon: "building.columns.fill", tint: .blue, titleKey: "tool.academicSystem") {
                            WebViewScreen(titleKey: "tool.academicSystem", url: APIConfig.jwcDesktopURL)
                        }
                        ToolCard(icon: "globe.asia.australia.fill", tint: .green, titleKey: "tool.schoolPortal") {
                            WebViewScreen(titleKey: "tool.schoolPortal", url: APIConfig.schoolHome)
                        }
                        ToolCard(icon: "books.vertical.fill", tint: .blue, titleKey: "tool.cnki") {
                            WebViewScreen(titleKey: "tool.cnki", url: APIConfig.cnkiWebvpn)
                        }
                        ToolCard(icon: "books.vertical", tint: .orange, titleKey: "tool.wanfang") {
                            WebViewScreen(titleKey: "tool.wanfang", url: APIConfig.wanfangWebvpn)
                        }
                    }
                    // 赞助开发者：快捷跳转下面单独一行（v1 风格，左侧爱心）
                    NavigationLink { SponsorView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(pink)
                            Text(String(localized: "tool.sponsor"))
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "tab.tools"))
        }
    }

    @ViewBuilder
    private func toolSection<Content: View>(_ titleKey: String, @ViewBuilder cards: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 12) {
                cards()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

/// 网格卡片（安卓 2.0 ToolCard 风格）：圆角浅色底图标 + 标题。
private struct ToolCard<Destination: View>: View {
    let icon: String
    let tint: Color
    let titleKey: String
    @ViewBuilder var destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ToolsView()
}
