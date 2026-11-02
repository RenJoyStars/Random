import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 历史记录（2.0）
//
// 一条时间线装下所有结果：点名、分组、八个随机工具。
// 课上用来翻「刚才点的是谁」，课后一键导出 CSV 交给班主任或教研组。
//
// 为什么单独做一页而不是塞进各工具页：
//   老师真正要问的是「这节课都抽了什么」，不是「骰子那一栏掷过几把」。

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    /// nil = 全部；其余是 `HistoryKind.pick` / `.group` / `Tool.rawValue`
    @State private var filter: String? = nil
    @State private var copied = false

    private var entries: [HistoryEntry] { model.historyEntries(kind: filter) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionLabel("概览")
                Bar {
                    HStack(spacing: 10) {
                        StatTile(value: "\(model.history.count)", label: "全部记录",
                                 symbol: "clock.arrow.circlepath")
                        StatTile(value: "\(model.pickEventTotal)", label: "点名",
                                 tint: .accentColor, symbol: "megaphone")
                        StatTile(value: "\(model.groupEventTotal)", label: "分组",
                                 symbol: "person.3.sequence")
                        Spacer(minLength: 0)
                    }
                }

                SectionLabel("筛选", count: filter == nil ? nil : "\(entries.count) 条") {
                    ClearButton(title: copied ? "已复制" : "复制 CSV",
                                symbol: copied ? "checkmark" : "doc.on.doc",
                                tint: copied ? .green : .accentColor,
                                disabled: model.history.isEmpty) {
                        Pasteboard.copy(model.historyCSV())
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                }

                Bar {
                    HStack(spacing: 12) {
                        Text("类型").font(.system(size: 13))
                        Spacer(minLength: 12)
                        Picker("", selection: $filter) {
                            Text("全部").tag(String?.none)
                            Text("点名").tag(String?.some(HistoryKind.pick))
                            Text("分组").tag(String?.some(HistoryKind.group))
                            ForEach(Tool.allCases) { tool in
                                Text(tool.title).tag(String?.some(tool.rawValue))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                }

                SectionLabel("记录", count: "\(entries.count) 条")

                Bar {
                    if entries.isEmpty {
                        EmptyRecords(text: model.history.isEmpty
                                     ? "还没有记录。点名、分组或抽取之后，这里会留下时间线。"
                                     : "这个筛选下没有记录。")
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                row(entry)
                                if index < entries.count - 1 {
                                    // 0.4 透明度的 Divider 在深色卡片上基本看不见，
                                    // 整列读起来像一堆悬空的行。改成实色细线，
                                    // 并从文字左缘（图标 18 + 间距 10 + 外层 14）起画 ——
                                    // 系统的列表分隔线是缩进的，不贯穿卡片。
                                    Rectangle()
                                        .fill(Color.semantic(.separator))
                                        .frame(height: 0.5)
                                        .padding(.leading, 42)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        exportCSV()
                    } label: {
                        Label("导出 CSV…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.history.isEmpty)

                    Button(role: .destructive) {
                        confirmClear()
                    } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.history.isEmpty)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)

                Text("导出的 CSV 四列：时间、类型、班级、结果。UTF-8 带 BOM，Excel 直接打开不乱码。历史只存本机，最多保留 \(AppModel.historyLimit) 条。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                Spacer(minLength: 2)
            }
            .padding(20)
        }
        .background(Color.clear)
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: HistoryKind.symbol(entry.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entry.isPick ? Color.accentColor : Color.secondary)
                .frame(width: 18)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(entry))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
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
        panel.nameFieldStringValue = "Random-历史记录-\(df.string(from: Date())).csv"
        panel.message = "导出全部历史记录（CSV）"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.historyCSV().write(to: url, atomically: true, encoding: .utf8)
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
