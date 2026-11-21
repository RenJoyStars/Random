import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    /// 边栏显示 / 隐藏交给系统的 `NavigationSplitView` 管理：
    /// 工具栏上的侧向栏按钮（系统自带）改的就是这个值，我们**不另造按钮**。
    ///
    /// 3.0 起不再监听窗口宽度去手动收起 / 撑宽边栏 —— 那套逻辑和用户拖窗口、
    /// 又和系统自己的折叠时机三方打架，表现就是「边栏忽隐忽现、拉宽后卡一下」。
    ///
    /// 窗口能拉到多窄。边栏 220 + 内容区舒适的 460，保证窗口不塌陷、边栏不闪退。
    static let minWindowWidth: CGFloat = 680
    static let minWindowHeight: CGFloat = 540

    /// 窄于这个宽度就自动收起边栏；与最小窗口宽度对齐，拖拽边框时绝不意外闪退收起。
    static let autoCollapseWidth: CGFloat = 680

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 侧边栏搜索。18 个班的名单一路排下来，没有搜索就只能靠滚。
    /// 只影响侧边栏显示，不写进 UserDefaults。
    @State private var query = ""

    /// 已展开的年级分组（存 `GradeGroup.id`）。
    ///
    /// 默认只展开当前班所在的那个年级；切换班级时把别的年级收起来 ——
    /// 老师上课只关心一个年级，另一组的十几个班占着屏幕纯属干扰。
    /// 不持久化：每次开 App 都回到「只展开你在用的那组」这个干净状态。
    @State private var expandedGrades: Set<String> = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 212, ideal: 240, max: 320)
        } detail: {
            detail
        }
        // 不再使用 .balanced 样式（balanced 会强制让边栏跟随窗口缩放等比伸缩，造成拖拽卡顿如橡皮筋）
        // 不再铺彩色光晕。
        //
        // 之前整窗叠了一张双色径向渐变（蓝 + 紫）当"玻璃要有东西可折射"的底，
        // 那是把内容层当装饰画布了：HIG 要求层级由布局和分组表达，
        // 背景保持系统的 windowBackground 就好 —— 边栏和工具栏的液态玻璃
        // 由系统自己负责折射，不需要我们再垫一层颜色去"喂"它。
        // 只设窗口下限，不再手动改窗口尺寸 / 手动折叠边栏（见上面的说明）
        .background(WindowMinSizeSetter(
            minSize: CGSize(width: Self.minWindowWidth, height: Self.minWindowHeight)
        ))
        // 直接把 .randomroster / .json 名单文件拖进窗口即可导入
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
        // 单向跟随窗口宽度：窄了自动收起边栏，宽了**什么都不做**。
        // 老师的需求很明确 —— 拉宽时不要自己把边栏弹出来，要手动点工具栏按钮。
        // 所以这里只有 if，没有 else：绝不把 columnVisibility 写回 .all。
        .background(WindowWidthReporter { width in
            guard width < Self.autoCollapseWidth else { return }
            guard columnVisibility != .detailOnly else { return }
            withAnimation(.snappy(duration: 0.2)) { columnVisibility = .detailOnly }
        })
        .onAppear {
            // 冷启动默认进入选班大厅，所有年级默认保持收起状态
            if case .classroom = model.selection { focusGrade(force: true) }
        }
        .onChange(of: model.classID) { _, _ in focusGrade() }
        .onChange(of: model.activeClasses.count) { _, _ in focusGrade(force: true) }
    }

    /// 仅在进入具体班级时展开该班所在的年级
    private func focusGrade(force: Bool = false) {
        guard case .classroom = model.selection else { return }
        guard let g = model.currentGrade else { return }
        let key = "g\(g.rawValue)"
        if force || !expandedGrades.contains(key) {
            withAnimation(.snappy(duration: 0.2)) { expandedGrades = [key] }
        }
    }

    // MARK: 名单导入（Mac）

    /// 通过「打开文件」面板导入名单。
    private func importRosterViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "randomroster"), .json]
            .compactMap { $0 }
        panel.message = "选择名单文件（.randomroster 或 .json）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        presentImportResult(model.loadRoster(url: url))
    }

    /// 处理从窗口拖入的文件。返回 true 表示我们接下了这个拖拽。
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            guard let url else { return }
            let result = model.loadRoster(url: url)
            DispatchQueue.main.async { presentImportResult(result) }
        }
        return true
    }

    /// 用系统弹窗反馈导入结果（成功 / 失败原因）。
    private func presentImportResult(_ result: (ok: Bool, message: String)) {
        let alert = NSAlert()
        alert.alertStyle = result.ok ? .informational : .warning
        alert.messageText = result.ok ? "名单已导入" : "导入失败"
        alert.informativeText = result.message
        alert.runModal()
    }

    // MARK: 侧边栏

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchField

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if model.hasClasses {
                        if query.isEmpty {
                            sideRow(title: "选班大厅", symbol: "square.grid.2x2",
                                    selected: model.selection == .welcome) {
                                withAnimation(.snappy(duration: 0.18)) {
                                    model.selection = .welcome
                                }
                            }
                        }

                        // 按年级分组，只展开当前班所在的那组（见 expandedGrades）。
                        ForEach(filteredGroups) { group in
                            gradeHeader(group)
                            // 用「卷帘」容器而不是裸 `if`：裸 if 插入行时，
                            // 下面的「随机工具」一边上移、新行一边淡入，两层会叠在一起。
                            CollapsibleRows(expanded: isExpanded(group)) {
                                VStack(spacing: 1) {
                                    ForEach(group.classes) { cls in
                                        classRow(cls)
                                    }
                                }
                            }
                        }
                    } else {
                        sideRow(title: "尚未导入名单", symbol: "square.and.arrow.down",
                                selected: false) {
                            importRosterViaPanel()
                        }
                    }

                    sectionLabel("随机工具")
                    ForEach(filteredTools) { tool in
                        sideRow(title: tool.title, symbol: tool.symbol,
                                selected: model.selection == .tool(tool)) {
                            withAnimation(.snappy(duration: 0.18)) {
                                model.selection = .tool(tool)
                            }
                        }
                    }

                    sectionLabel("记录")
                    // 没有记录时不挂徽标 —— 一个「0」在侧边栏里纯属噪声。
                    sideRow(title: "历史记录", symbol: "clock.arrow.circlepath",
                            selected: model.selection == .history,
                            badge: model.history.isEmpty ? nil : "\(model.history.count)") {
                        withAnimation(.snappy(duration: 0.18)) {
                            model.selection = .history
                        }
                    }

                    if !query.isEmpty, filteredGroups.isEmpty, filteredTools.isEmpty {
                        Text("没有匹配的班级或工具")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 搜索框自己画：`.searchable(placement: .sidebar)` 只能挂在 List 上，
    /// 这里换成普通输入框，样式和系统搜索框保持一致。
    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("搜索班级或工具", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("清空搜索")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 3)
    }

    /// 年级标题行：整行可点，箭头带旋转动画，收起时一眼看清班数。
    private func gradeHeader(_ group: AppModel.GradeGroup) -> some View {
        Button {
            setExpanded(group, to: !isExpanded(group))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded(group) ? 90 : 0))
                    .animation(.snappy(duration: 0.2), value: isExpanded(group))
                    .frame(width: 10)

                Text(group.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondary)

                Spacer(minLength: 0)

                Text("\(group.count)")
                    .font(.system(size: Type.tiny, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isExpanded(group) ? "收起\(group.title)" : "展开\(group.title)")
    }

    /// 侧边栏的一行（班级 / 工具 / 历史都用它，样式统一，带原生悬停反馈）。
    private func sideRow(title: String, symbol: String, selected: Bool,
                         trailing: String? = nil,
                         trailingTint: Color = .secondary,
                         badge: String? = nil,
                         indent: Bool = false,
                         action: @escaping () -> Void) -> some View {
        SidebarRowButton(title: title, symbol: symbol, selected: selected,
                         trailing: trailing, trailingTint: trailingTint,
                         badge: badge, indent: indent, action: action)
    }

    /// 搜索时按班号 / 班名过滤，并且**保留当前选中项** ——
    /// List(selection:) 的选中行一旦被筛掉，系统会把 selection 置空，
    /// 兜底逻辑就会把人拽回班级页，边搜边跳很难用。
    private var filteredGroups: [AppModel.GradeGroup] {
        guard !query.isEmpty else { return model.gradeGroups }
        return model.gradeGroups.compactMap { group in
            let list = group.classes.filter {
                $0.shortTitle.localizedStandardContains(query)
                    || $0.title.localizedStandardContains(query)
                    || $0.id == model.classID
            }
            return list.isEmpty
                ? nil
                : AppModel.GradeGroup(grade: group.grade, classes: list)
        }
    }

    private var filteredTools: [Tool] {
        guard !query.isEmpty else { return Tool.allCases }
        return Tool.allCases.filter {
            $0.title.localizedStandardContains(query)
                || model.selection == .tool($0)
        }
    }

    /// 展开 / 收起某个年级。
    ///
    /// 动画必须包在 `withAnimation` 里：侧边栏是自绘的 `ScrollView + LazyVStack`，
    /// 高度变化靠 SwiftUI 的布局动画完成（`CollapsibleRows` 负责量高度 + 裁切），
    /// 不像 `List` 那样插入行没有动画。
    private func setExpanded(_ group: AppModel.GradeGroup, to value: Bool) {
        withAnimation(.snappy(duration: 0.22)) {
            if value {
                expandedGrades.insert(group.id)
            } else {
                expandedGrades.remove(group.id)
            }
        }
    }

    private func isExpanded(_ group: AppModel.GradeGroup) -> Bool {
        // 搜索时全部展开：命中的班要能一眼看见，不然还得先点开分组。
        query.isEmpty ? expandedGrades.contains(group.id) : true
    }

    private func classRow(_ cls: ClassRoster.SchoolClass) -> some View {
        sideRow(title: cls.shortTitle,
                symbol: "graduationcap",
                selected: model.selection == .classroom(cls.id),
                trailing: "\(model.drawnCount(of: cls.id))/\(model.names(of: cls.id).count)",
                trailingTint: model.drawnCount(of: cls.id) > 0 ? .accentColor : .secondary,
                indent: true) {
            withAnimation(.snappy(duration: 0.18)) {
                model.selection = .classroom(cls.id)
            }
        }
    }

    // MARK: 详情

    private var detail: some View {
        detailView(for: model.selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title(for: model.selection))
        .navigationSubtitle(subtitle(for: model.selection))
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .welcome:
            if model.hasClasses { WelcomeView() } else { NoRosterView() }
        case .classroom:
            // 还没导入名单时，班级页显示引导（随机工具不受影响，照样能用）
            if model.hasClasses { ClassroomView() } else { NoRosterView() }
        case .tool(let tool):
            toolView(tool)
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func toolView(_ tool: Tool) -> some View {
        switch tool {
        case .grouping:          GroupingView()
        case .sequence:          SequenceView()
        case .randomNumber:      RandomNumberView()
        case .dice:              DiceView()
        case .coin:              CoinView()
        case .card:              CardView()
        case .color:             ColorView()
        case .letter:            LetterView()
        case .rockPaperScissors: RPSView()
        case .yesNo:             YesNoView()
        case .groupPick:         GroupPickView()
        case .countdown:         CountdownView()
        }
    }

    // MARK: 标题

    private func title(for item: SidebarItem) -> String {
        switch item {
        case .welcome:           return "选班大厅"
        case .classroom(let id): return model.hasClasses ? model.title(of: id) : "班级"
        case .tool(let t):       return t.title
        case .history:           return "历史记录"
        case .settings:          return "设置"
        }
    }

    private func subtitle(for item: SidebarItem) -> String {
        switch item {
        case .welcome:
            guard model.hasClasses else { return "尚未导入名单" }
            return "\(model.activeClasses.count) 个班级就绪 · 点击进入上课"
        case .classroom(let id):
            guard model.hasClasses else { return "尚未导入名单" }
            return "\(model.names(of: id).count) 人 · 已抽 \(model.drawnCount(of: id))"
        case .tool(let t):
            return t.actionTitle
        case .history:
            return "\(model.history.count) 条记录 · 可导出 CSV"
        case .settings:
            return "外观 · 音效 · 名单"
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                importRosterViaPanel()
            } label: {
                Label("导入名单", systemImage: "square.and.arrow.down")
            }
            .help("导入一份 .randomroster 名单文件；也可以直接把文件拖进窗口")

            Button {
                model.soundOn.toggle()
            } label: {
                Label(model.soundOn ? "音效已开" : "音效已关",
                      systemImage: model.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .help(model.soundOn ? "音效已开，点一下关闭（⇧⌘M）" : "音效已关，点一下打开（⇧⌘M）")

            Button {
                model.undoCurrent()
            } label: {
                Label("撤销", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)
            .help("撤销上一次（仅班级点名）")

            Button(role: .destructive) {
                withAnimation(.snappy(duration: 0.2)) { model.resetCurrent() }
            } label: {
                Label("清空记录", systemImage: "trash")
            }
            .disabled(!model.hasRecords)
            .help("清空当前页面的记录")
        }
    }
}

// MARK: - 未导入名单时的引导页

/// 应用不再内置任何名单，所以第一次打开一定是这个页面。
/// 说清「要做什么」和「怎么做」，并给一个直接能点的导入入口。
struct NoRosterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: "person.3.sequence")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("还没有班级名单")
                    .font(.title2.weight(.semibold))
                Text("Random 不内置任何名单，导入你自己的名单后即可开始点名。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                importRoster()
            } label: {
                Label("导入名单…", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            VStack(spacing: 4) {
                Text("也可以直接把 .randomroster 文件拖进窗口，或双击文件打开。")
                Text("没有名单文件？把 Excel 交给 AI，让它转成 .randomroster 即可。")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func importRoster() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "randomroster"), .json].compactMap { $0 }
        panel.message = "选择名单文件（.randomroster 或 .json）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        presentResult(model.loadRoster(url: url))
    }

    private func presentResult(_ result: (ok: Bool, message: String)) {
        let alert = NSAlert()
        alert.alertStyle = result.ok ? .informational : .warning
        alert.messageText = result.ok ? "名单已导入" : "导入失败"
        alert.informativeText = result.message
        alert.runModal()
    }
}

/// 卷帘式展开：容器高度做动画，溢出的部分裁掉。
///
/// 为什么不用裸 `if`：SwiftUI 插入子视图时，新行按最终位置摆放并淡入，
/// 而它下面的兄弟节点同时在往上滑 —— 两边叠在一起，展开途中会看到文字重影。
/// 这里把内容先量出真实高度，再把外层高度在 0 ↔ 全高之间做动画并裁切，
/// 视觉上就是「从上往下掀开」，底下内容始终在新行之外。
struct CollapsibleRows<Content: View>: View {
    var expanded: Bool
    let content: Content

    @State private var fullHeight: CGFloat = 0

    init(expanded: Bool, @ViewBuilder content: () -> Content) {
        self.expanded = expanded
        self.content = content()
    }

    var body: some View {
        content
            // 高度不受外层约束，量到的永远是「完全展开」时的高度
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { fullHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in fullHeight = h }
                }
            }
            // 还没量到高度时（首帧）先按自然高度排，避免开 App 时闪一下空白
            .frame(height: expanded ? (fullHeight > 0 ? fullHeight : nil) : 0,
                   alignment: .top)
            .clipped()
    }
}

// MARK: - 选班大厅（课堂就绪）

/// 带原生悬停高亮的侧边栏行按钮。
private struct SidebarRowButton: View {
    let title: String
    let symbol: String
    let selected: Bool
    var trailing: String? = nil
    var trailingTint: Color = .secondary
    var badge: String? = nil
    var indent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Color.white : Color.accentColor)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color.white : Color.primary)

                Spacer(minLength: 4)

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(selected ? Color.white.opacity(0.9) : trailingTint)
                }

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(selected ? Color.clear : Color.primary.opacity(0.08),
                                    in: Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Color.accentColor : (hovering ? Color.primary.opacity(0.06) : Color.clear))
        }
        .onHover { hovering = $0 }
        .padding(.leading, indent ? 13 : 0)
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    private var totalStudents: Int {
        model.activeClasses.reduce(0) { $0 + $1.names.count }
    }

    private var recentClass: ClassRoster.SchoolClass? {
        guard !model.classID.isEmpty else { return nil }
        return model.activeClasses.first { $0.id == model.classID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LayoutMetrics.pageSpacing) {
                heroStage

                classesSection

                quickToolsSection

                footerInfo
            }
            .macPagePadding()
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: 顶部就绪舞台

    private var heroStage: some View {
        StageCard(minHeight: 136, ambientTint: .accentColor) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("课堂就绪 · CLASS READY")
                        .font(.system(size: Type.caption, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())

                Text("今天上哪个班？")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("点击下方班级卡片立即进入点名；亦可通过工具直达课堂互动活动")
                    .font(.system(size: Type.body))
                    .foregroundStyle(Color.secondary)

                if let recent = recentClass {
                    let drawn = model.drawnCount(of: recent.id)
                    let total = model.names(of: recent.id).count
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            model.selection = .classroom(recent.id)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13))
                            Text("继续 \(recent.shortTitle) 班（\(drawn)/\(total)）")
                                .font(.system(size: Type.body, weight: .medium))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: 班级网格

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(model.gradeGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(group.title)
                            .font(.system(size: Type.title, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text("\(group.classes.count) 个班")
                            .font(.system(size: Type.caption))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 14)], spacing: 14) {
                        ForEach(group.classes) { cls in
                            ClassTileCard(cls: cls)
                        }
                    }
                }
            }
        }
    }

    // MARK: 课堂常用工具

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("课堂常用工具")
                    .font(.system(size: Type.title, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)], spacing: 12) {
                QuickToolTile(tool: .grouping, subtitle: "全班随机拆分小组")
                QuickToolTile(tool: .groupPick, subtitle: "抽取小组或二/四部合唱")
                QuickToolTile(tool: .countdown, subtitle: "课堂互动与答题倒计时")
                QuickToolTile(tool: .sequence, subtitle: "全班乱序出场表演")
            }
        }
    }

    // MARK: 底部信息

    private var footerInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("当前名单：\(model.importedRosterName ?? "已导入名单") · \(model.activeClasses.count) 个班级 · 共计 \(totalStudents) 人")
                .font(.system(size: Type.caption))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

/// 课堂常用工具入口磁贴（带悬停微动效）
private struct QuickToolTile: View {
    @Environment(AppModel.self) private var model
    let tool: Tool
    let subtitle: String
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                model.selection = .tool(tool)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(isHovered ? 0.16 : 0.10),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(.system(size: Type.body, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.system(size: Type.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: LayoutMetrics.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08),
                                  lineWidth: isHovered ? 1.0 : 0.8)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .animation(.snappy(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 班级磁贴卡片

struct ClassTileCard: View {
    @Environment(AppModel.self) private var model
    let cls: ClassRoster.SchoolClass
    @State private var isHovered = false

    private var drawn: Int { model.drawnCount(of: cls.id) }
    private var total: Int { model.names(of: cls.id).count }
    private var progress: Double { total > 0 ? Double(drawn) / Double(total) : 0 }

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                model.selection = .classroom(cls.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(cls.shortTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    statusBadge
                }

                Text(cls.title)
                    .font(.system(size: Type.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // 进度条与数字
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(drawn > 0 ? "已抽 \(drawn) 人" : "待开抽")
                            .font(.system(size: Type.caption, weight: .medium))
                            .foregroundStyle(drawn > 0 ? Color.accentColor : Color.secondary)
                        Spacer()
                        Text("共 \(total) 人")
                            .font(.system(size: Type.caption))
                            .foregroundStyle(.tertiary)
                    }

                    ThinProgressBar(
                        progress: progress,
                        tint: drawn >= total && total > 0 ? Color.green : Color.accentColor,
                        height: 5
                    )
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: LayoutMetrics.stageCornerRadius, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                    .overlay {
                        RoundedRectangle(cornerRadius: LayoutMetrics.stageCornerRadius, style: .continuous)
                            .strokeBorder(isHovered ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
                                         lineWidth: isHovered ? 1.2 : 0.8)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .animation(.snappy(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if drawn == 0 {
            Text("待开抽")
                .font(.system(size: Type.caption, weight: .medium))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: Capsule())
        } else if drawn >= total && total > 0 {
            Text("已点毕")
                .font(.system(size: Type.caption, weight: .medium))
                .foregroundStyle(Color.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12), in: Capsule())
        } else {
            Text("已抽 \(Int(progress * 100))%")
                .font(.system(size: Type.caption, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
    }
}
