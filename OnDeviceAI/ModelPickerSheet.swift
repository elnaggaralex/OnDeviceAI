import SwiftUI

struct ModelPickerSheet: View {
    private let onDone: (String) -> Void
    @State private var viewModel: ModelPickerViewModel
    @Environment(\.dismiss) private var dismiss

    init(selectedModel: String, onDone: @escaping (String) -> Void) {
        self.onDone = onDone
        _viewModel = State(initialValue: ModelPickerViewModel(selectedModel: selectedModel))
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
                    ForEach(viewModel.filteredModels) { model in
                        ModelOptionCard(
                            model: model,
                            isSelected: viewModel.selectedModel == model.name
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                viewModel.selectModel(model)
                            }
                        }
                    }

                    if viewModel.filteredModels.isEmpty {
                        ContentUnavailableView.search(text: viewModel.query)
                            .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }

            DeviceStorageFooter()
        }
        .background(Colors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
