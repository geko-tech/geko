import SwiftUI

struct SourcesEditorView<T: ISourcesEditorViewOutput>: View {
    // MARK: - Attributes
    
    @StateObject var viewState: T
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Available Modules").font(.cellTitle).padding([.leading, .top])
            searchBar
            modulesView
            Divider()
            regexesFullView
            bottomView
        }
        .frame(minWidth: 400, minHeight: 600, maxHeight: 800)
        .onAppear {
            viewState.onAppear()
        }
    }
    
    var regexTextEdit: some View {
        HStack {
            TextField("Enter regular expression, for example 'FinHealth.*'", text: $viewState.modulesProvider.regexText)
            Button("Add", action: viewState.modulesProvider.addRegex)
                .buttonStyle(.borderedProminent)
        }
    }
    
    var searchBar: some View {
        HStack {
            Image.search
            TextField("Search", text: $viewState.modulesProvider.searchText)
        }.padding([.leading, .trailing])
    }
    
    var regexesEmptyView: some View {
        VStack {
            Spacer()
            Text("No regular expressions added")
                .multilineTextAlignment(.center)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var regexesFullView: some View {
        VStack(alignment: .leading) {
            Text("Regular expressions").font(.cellTitle)
            regexTextEdit
            ScrollView() {
                VStack {
                    if viewState.modulesProvider.regexes.isEmpty {
                        regexesEmptyView
                    } else {
                        regexesView
                    }
                }.padding(.top, 4.0)
            }
        }
        .frame(minHeight: 110, maxHeight: 150)
        .fixedSize(horizontal: false, vertical: true)
        .padding([.leading, .trailing, .bottom])
    }
    
    var regexesView: some View {
        RegexListView(
            removeAction: viewState.modulesProvider.removeRegex(at:),
            regexes: $viewState.modulesProvider.regexes
        )
    }
    
    var modulesView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                filtersView
                ModulesListView(
                    title: "Modules",
                    didSelectAction: viewState.modulesProvider.didSelectModule(_:),
                    modules: $viewState.modulesProvider.filteredAllModules
                )
            }.padding()
        }
        .frame(maxHeight: 650)
    }
    
    var filtersView: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle(isOn: $viewState.modulesProvider.onlyAdded, label: { Text("Only Added") })
                    .onChange(of: viewState.modulesProvider.onlyAdded) {
                        viewState.modulesProvider.updateSearch()
                }
                Toggle(isOn: $viewState.modulesProvider.fromRegex, label: { Text("Added from regular expressions") })
                    .onChange(of: viewState.modulesProvider.fromRegex) {
                        viewState.modulesProvider.updateSearch()
                }
            }
            HStack {
                Toggle(isOn: $viewState.modulesProvider.showTests, label: { Text("Show Tests") })
                    .onChange(of: viewState.modulesProvider.showTests) {
                        viewState.modulesProvider.updateSearch()
                }
                Toggle(isOn: $viewState.modulesProvider.showMocks, label: { Text("Show Mocks") })
                    .onChange(of: viewState.modulesProvider.showMocks) {
                        viewState.modulesProvider.updateSearch()
                }
            }
        }
    }
    
    var bottomView: some View {
        HStack(alignment: .bottom) {
            Spacer()
            Button("Cancel", action: viewState.close)
            Button("Apply", action: viewState.apply)
                .buttonStyle(.borderedProminent)
        }.padding([.bottom, .trailing])
    }
}

