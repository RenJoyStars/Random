import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 历史记录（2.0）
//
// 一条时间线装下所有结果：点名、分组、各随机工具。
// 课上用来翻「刚才点的是谁」，课后一键导出 CSV 交给班主任或教研组。
// 遵循 macOS 27 Golden Gate 视觉语言：KPI 数据卡片、时间线胶囊与直观过滤交互。

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    /// nil = 全部；其余是 `HistoryKind.pick` / `.group` / `Tool.rawValue`
    @State private var filter: String? = nil
    @State private var classFilter: String? = nil
    @State private var copied = false

    private var entries: [HistoryEntry] { model.historyEntries(kind: filter, classID: classFilter) }

    var body: some View {
        ScrollView {
            VStack(spacing: LayoutMetrics.pageSpacing) {
                // MARK: 概览 KPI 卡片
                SectionLabel("概览")
                HStack(spacing: 12) {
                    kpiTile(value: "\(model.history.count)",
                            label: "全部记录",
                            symbol: "clock.arrow.circlepath",
                            tint: .primary)
                    kpiTile(value: "\(model.pickEventTotal)",
                            label: "班级点名",
                            symbol: "megaphone.fill",
                            tint: .accentColor)
                    kpiTile(value: "\(model.groupEventTotal)",
                            label: "随机分组",
                            symbol: "person.3.sequence.fill",
                            tint: .purple)
                }

                // MARK: 筛选栏
                SectionLabel("筛选", count: (filter == nil && classFilter == nil) ? nil : "\(entries.count) 条") {
                    ClearButton(title: copied ? "已复制" : "复制 CSV",
                                symbol: copied ? "checkmark" : "doc.on.doc",
                                tint: copied ? .green : .accentColor,
                                disabled: entries.isEmpty) {
                        Pasteboard.copy(model.historyCSV(kind: filter, classID: classFilter))
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                }

                Bar {
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("类型").font(.system(size: 13, weight: .medium))
                            Picker("", selection: $filter) {
                                Text("全部类型").tag(String?.none)
                                Text("点名").tag(String?.some(HistoryKind.pick))
                                Text("分组").tag(String?.some(HistoryKind.group))
                                ForEach(Tool.allCases) { tool in
                                    Text(tool.title).tag(String?.some(tool.rawValue))
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: 150)
                        }

                        if model.hasClasses {
                            Divider().frame(height: 18)
                            HStack(spacing: 6) {
                                Image(systemName: "graduationcap")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text("班级").font(.system(size: 13, weight: .medium))
                                Picker("", selection: $classFilter) {
                                    Text("全部班级").tag(String?.none)
                                    ForEach(model.activeClasses) { cls in
                                        Text(cls.shortTitle).tag(String?.some(cls.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: 150)
                            }
                        }

                        Spacer(minLength: 0)

                        if filter != nil || classFilter != nil {
                            Button("重置筛选") {
                                withAnimation(.snappy(duration: 0.18)) {
                                    filter = nil
                                    classFilter = nil
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: Type.caption))
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                // MARK: 记录列表
                SectionLabel("记录时间线", count: "\(entries.count) 条")

                CardGroup {
                    if entries.isEmpty {
                        EmptyRecords(text: model.history.isEmpty
                                     ? "还没有记录。点名、分组或抽取之后，这里会留下时间线。"
                                     : "当前筛选条件下没有记录。")
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                row(entry)
                                if index < entries.count - 1 {
                                    Rectangle()
                                        .fill(Color.semantic(.separator).opacity(0.6))
                                        .frame(height: 0.5)
                                        .padding(.leading, 46)
                                }
                            }
                        }
                    }
                }

                // MARK: 底部操作
                HStack(spacing: 12) {
                    Button {
                        exportCSV()
                    } label: {
                        Label("导出 CSV 文件…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(model.history.isEmpty)

                    Button(role: .destructive) {
                        confirmClear()
                    } label: {
                        Label("清空历史记录", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(model.history.isEmpty)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)

                Text("导出的 CSV 包含四列：时间、类型、班级、结果。UTF-8 带 BOM 编码，Excel 直接打开绝无乱码。所有数据仅保存在本机，最多保留 \(AppModel.historyLimit) 条。")
                    .font(.system(size: Type.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                Spacer(minLength: 12)
            }
            .macPagePadding()
        }
        .background(Color.clear)
    }

    // MARK: KPI 卡片

    private func kpiTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: Type.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: LayoutMetrics.cardCornerRadius, style: .continuous)
                .fill(Color.semantic(.controlBackground))
                .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: LayoutMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.semantic(.separator).opacity(0.7), lineWidth: 0.5)
                }
        }
    }

    // MARK: 行布局

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: HistoryKind.symbol(entry.kind))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(badgeTint(for: entry))
                .frame(width: 28, height: 28)
                .background(badgeTint(for: entry).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(entry))
                    .font(.system(size: Type.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: Type.caption).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.semantic(.controlBackground))
    }

    private func badgeTint(for entry: HistoryEntry) -> Color {
        if entry.isPick { return .accentColor }
        if entry.kind == HistoryKind.group { return .purple }
        return .secondary
    }

    private func subtitle(_ entry: HistoryEntry) -> String {
        var parts = [HistoryKind.title(entry.kind)]
        if !entry.classID.isEmpty { parts.append(model.title(of: entry.classID)) }
        parts.append(entry.date.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }

    // MARK: 导出 / 清空

    private func exportCSV() {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyyMMdd-HHmm"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let classSuffix = classFilter.flatMap { id in model.title(of: id) } ?? "全部"
        panel.nameFieldStringValue = "Random-历史记录-\(classSuffix)-\(df.string(from: Date())).csv"
        panel.message = "导出历史记录（CSV）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.historyCSV(kind: filter, classID: classFilter).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "导出失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "清空全部历史记录？"
        alert.informativeText = "将删除 \(model.history.count) 条记录，班级页的「被点最少」统计也会随之清零。"
            + "已经导出的 CSV 不受影响。此操作不能撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            model.clearHistory()
        }
    }
}
