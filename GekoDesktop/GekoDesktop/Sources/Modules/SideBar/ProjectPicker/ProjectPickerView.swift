import SwiftUI

struct ProjectPickerView<T: IProjectPickerViewStateOutput>: View {
    // MARK: - Attributes
    
    @StateObject var viewState: T
    
    // MARK: - UI
    
    var body: some View {
        VStack {
            switch viewState.state {
            case .empty:
                Button("Choose Project") { 
                    viewState.addButtonDidTapped()
                }
            case .project(let projectName):
                HStack {
                    Image.appLogo.resizable().frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(projectName).font(.cellTitle).lineLimit(1)
                        Button("Select another") { 
                            viewState.selectButtonDidTapped()
                        }.buttonStyle(.link).font(.system(size: 10))
                    }
                    Spacer()
                }.padding([.leading, .top], 8)
            }
        }.sheet(isPresented: $viewState.showProjectsList, content: { 
            projectsListView
        })
    }
    
    var projectsListView: some View {
        VStack {
            ForEach(viewState.allProjects) { project in
                VStack {
                    HStack {
                        Image.appLogo.resizable().frame(width: 16, height: 16)
                        Text(project)
                        Spacer()
                        Button("Select") {
                            viewState.select(project)
                        }
                    }
                    Divider().padding(.leading, 8)
                }
                
            }
            HStack {
                Button("Cancel") {
                    viewState.showProjectsList = false
                }
                Spacer()
                Button("Add New Project") {
                    viewState.addButtonDidTapped()
                }.buttonStyle(.borderedProminent)
            }
        }.padding()
    }
}
