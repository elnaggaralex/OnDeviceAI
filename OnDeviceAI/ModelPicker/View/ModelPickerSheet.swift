import SwiftUI

struct ModelPickerSheet: View {
    private let onDone: (String) -> Void
    private let downloadManager: ModelDownloadManager
    @State private var viewModel: ModelPickerViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        selectedModel: String,
        downloadManager: ModelDownloadManager,
        onDone: @escaping (String) -> Void
    ) {
        self.onDone = onDone
        self.downloadManager = downloadManager
        _viewModel = State(
            initialValue: ModelPickerViewModel(
                selectedModel: selectedModel,
                downloadManager: downloadManager
            )
        )
    }

    private var queryBinding: Binding<String> {
        Binding(get: { viewModel.query }, set: { viewModel.search(for: $0) })
    }

    private var filterBinding: Binding<ModelPickerFilter> {
        Binding(get: { viewModel.selectedFilter }, set: { viewModel.selectFilter($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            ModelPickerHeaderView {
                onDone(viewModel.selectedModel)
                dismiss()
            }

            ModelSearchField(query: queryBinding)
                .padding(.top, 16)

            ModelFilterBar(selection: filterBinding)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading && viewModel.filteredModels.isEmpty {
                        ProgressView("Loading Core AI Community models…")
                            .tint(Colors.blue)
                            .padding(.top, 32)
                    }

                    if let errorMessage = viewModel.errorMessage, viewModel.models.isEmpty {
                        ContentUnavailableView {
                            Label("Couldn't Load Models", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Try Again") {
                                Task { await viewModel.loadModels() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 24)
                    }

                    ForEach(viewModel.filteredModels) { model in
                        let download = downloadManager.download(for: model.repositoryID)
                        ModelOptionCard(
                            model: model,
                            isSelected: viewModel.selectedModel == model.repositoryID,
                            isDownloaded: downloadManager.isDownloaded(repositoryID: model.repositoryID),
                            isDownloading: download != nil,
                            downloadProgress: download?.progress,
                            downloadError: downloadManager.error(for: model.repositoryID),
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    viewModel.selectModel(model)
                                }
                            },
                            onDownload: { viewModel.download(model) }
                        )
                    }

                    if !viewModel.isLoading, viewModel.errorMessage == nil, viewModel.filteredModels.isEmpty {
                        ContentUnavailableView.search(text: viewModel.query)
                            .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }

        }
        .background(Colors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task {
            await viewModel.loadModels()
        }
    }
}
