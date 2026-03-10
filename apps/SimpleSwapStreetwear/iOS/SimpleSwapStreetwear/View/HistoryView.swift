import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    emptyState
                } else {
                    List {
                        if viewModel.history.count >= 2 {
                            Section("Performance") {
                                latencyChart
                            }
                        }

                        Section("Sessions (\(viewModel.history.count))") {
                            ForEach(viewModel.history) { record in
                                HistoryRow(record: record)
                            }
                            .onDelete(perform: viewModel.deleteHistoryItem)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !viewModel.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearHistory()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Save a color swap to see it here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var latencyChart: some View {
        Chart {
            ForEach(Array(viewModel.history.reversed().enumerated()), id: \.element.id) { index, record in
                BarMark(
                    x: .value("Session", index + 1),
                    y: .value("Latency (ms)", record.latencyMs)
                )
                .foregroundStyle(AppTheme.gradient)
                .cornerRadius(4)
            }
        }
        .frame(height: 160)
        .chartYAxisLabel("ms")
        .chartXAxisLabel("Session")
    }
}

struct HistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            if let image = SessionRecord.loadImage(name: record.resultImagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.colorName)
                    .font(.subheadline.bold())

                Text(record.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.0f ms", record.latencyMs))
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

