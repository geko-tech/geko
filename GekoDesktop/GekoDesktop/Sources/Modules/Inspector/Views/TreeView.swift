import SwiftUI

// MARK: - Constants

fileprivate enum ViewConstants {
    static let leafViewArrowStackSpacer: CGFloat = 5
    static let leafViewStackSpacer: CGFloat = 1
    static let leafViewDelta: CGFloat = 10
    static let imageSize: CGFloat = 6
    
    static let verticalSpacer: CGFloat = 2
    static let containerWidthSpacer: CGFloat = 3
    
    static let selectedCornerRadius: CGFloat = 4
    static let selectedColorAlpha: CGFloat = 0.6
}

var isClick: Bool = false
var showingDataTree: [ProjectTree] = []
var toolbarY: CGFloat = -1
var scrollViewY: CGFloat = .infinity
var isMoveBottom: Bool = false

struct TreeView: View {
    @State var projectTree: [ProjectTree]
    
    @State private var expanded: [ProjectTree] = []
    @State private var selected: ProjectTree? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack {
                    HStack {
                        if !projectTree.isEmpty {
                            Spacer().frame(width: ViewConstants.containerWidthSpacer)
                            LazyVStack(alignment: .leading, spacing: ViewConstants.verticalSpacer / 2) {
                                ForEach(projectTree[0].children ?? [], id: \.id) { tree in
                                    AnyView(createCell(tree, depth: 0)).listRowSeparator(.hidden)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Spacer().frame(width: ViewConstants.containerWidthSpacer)
                        }
                    }
                }
            }
            .toolbarBackground(.windowBackground)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newValue in
                scrollViewY = newValue.maxY
            }
            .onChange(of: selected) { _, newSelectedTree in
                guard !isClick else {
                    isClick = false
                    return
                }
                
                guard let newSelectedTree else { return }
                
                let isFocused = showingDataTree.contains(newSelectedTree)
                
                guard !isFocused else { return }
                
                withAnimation {
                    proxy.scrollTo(makeId(for: newSelectedTree),
                                   anchor: isMoveBottom ? .bottom : .top)
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            guard let selectTree = selected else { return .ignored }
            
            if let prev = findPrev(for: selectTree) {
                isMoveBottom = false
                toggleSelected(prev)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard let selectTree = selected else { return .ignored }
            
            if let next = findNext(for: selectTree) {
                isMoveBottom = true
                toggleSelected(next)
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard let selectTree = selected else { return .ignored }
            
            if selectTree.children?.isEmpty == false {
                expanded.append(selectTree)
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard let selectTree = selected else { return .ignored }
            
            if selectTree.children?.isEmpty == false && expanded.contains(selectTree) {
                clearShowing(for: selectTree.children ?? [])
                expanded.removeAll(where: { $0 == selectTree })
            } else if selectTree.parent?.parent != nil {
                selected = selectTree.parent
                isMoveBottom = false
            }
            return .handled
        }
    }
    
    private func clearShowing(for tree: [ProjectTree]) {
        for child in tree {
            clearShowing(for: child.children ?? [])
            showingDataTree.removeAll(where: { $0 == child })
        }
    }
    
    private func makeId(for tree: ProjectTree) -> String {
        if expanded.contains(tree) {
            return "\(tree.name)+\(tree.childrenCount)"
        }
        
        return tree.name + (tree.parent?.name ?? "")
    }
    
    private func toggleExpanded(_ tree: ProjectTree) {
        if expanded.contains(tree) {
            clearShowing(for: tree.children ?? [])
            expanded.removeAll(where: { $0 == tree })
        } else {
            expanded.append(tree)
        }
    }
    
    private func toggleSelected(_ tree: ProjectTree) {
        selected = tree
    }
    
    private func createCell(_ tree: ProjectTree, depth: CGFloat = 0) -> any View {
        if tree.children?.isEmpty ?? true {
            return leafView(tree, depth)
                .onTapGesture {
                    isClick = true
                    toggleSelected(tree)
                }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { newValue in
                    if newValue.minY < toolbarY {
                        showingDataTree.removeAll(where: { $0 == tree })
                    }
                    if newValue.maxY > scrollViewY {
                        showingDataTree.removeAll(where: { $0 == tree })
                    }
                    if newValue.minY >= toolbarY
                        && newValue.maxY < scrollViewY {
                        showingDataTree.append(tree)
                    }
                }
                .id(makeId(for: tree))
        } else if !expanded.contains(tree) {
            return leafViewWithArrow(tree, depth, isExpanded: false)
                .onTapGesture {
                    isClick = true
                    toggleExpanded(tree)
                    toggleSelected(tree)
                }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { newValue in
                    if newValue.minY < toolbarY {
                        showingDataTree.removeAll(where: { $0 == tree })
                    }
                    if newValue.maxY > scrollViewY {
                        showingDataTree.removeAll(where: { $0 == tree })
                    }
                    if newValue.minY >= toolbarY
                        && newValue.maxY < scrollViewY {
                        showingDataTree.append(tree)
                    }
                }
                .id(makeId(for: tree))
        } else {
            return LazyVStack(alignment: .leading, spacing: 2) {
                leafViewWithArrow(tree, depth, isExpanded: true)
                    .onTapGesture {
                        isClick = true
                        toggleExpanded(tree)
                        toggleSelected(tree)
                    }
                    .id(makeId(for: tree))
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { newValue in
                        if newValue.minY < toolbarY {
                            showingDataTree.removeAll(where: { $0 == tree })
                        }
                        if newValue.maxY > scrollViewY {
                            showingDataTree.removeAll(where: { $0 == tree })
                        }
                        if newValue.minY >= toolbarY
                            && newValue.maxY < scrollViewY {
                            showingDataTree.append(tree)
                        }
                    }
                ForEach(tree.children ?? []) { child in
                    AnyView(createCell(child, depth: depth + 1))
                }
            }.id(makeId(for: tree))
        }
    }
    
    private func leafView(_ projectTree: ProjectTree, _ depth: CGFloat) -> some View {
        VStack {
            Spacer().frame(height: ViewConstants.verticalSpacer)
            HStack {
                Spacer().frame(width: ViewConstants.leafViewDelta + (ViewConstants.leafViewArrowStackSpacer
                                       + ViewConstants.imageSize) * (depth + 1))
                projectTree.image(isSelected: selected == projectTree)
                Spacer().frame(width: ViewConstants.leafViewStackSpacer)
                Text(projectName(from: projectTree))
                    .lineLimit(1)
                    .foregroundStyle(selected == projectTree ? .revSelected : (projectTree.isCached ? .gray : .primary))
            }.frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: ViewConstants.verticalSpacer)
        }
        .background(selected == projectTree ? .selectBlue.opacity(ViewConstants.selectedColorAlpha) : .clear)
        .cornerRadius(ViewConstants.selectedCornerRadius)
    }
    
    private func leafViewWithArrow(_ projectTree: ProjectTree, _ depth: CGFloat, isExpanded: Bool) -> some View {
        VStack {
            Spacer().frame(height: ViewConstants.verticalSpacer)
            HStack {
                Spacer().frame(width: ViewConstants.leafViewDelta + (ViewConstants.imageSize
                                       + ViewConstants.leafViewArrowStackSpacer) * depth)
                (isExpanded ? Image.didOpenArrow : Image.willOpenArrow).frame(width: ViewConstants.imageSize,
                                                                              height: ViewConstants.imageSize)
                Spacer().frame(width: ViewConstants.leafViewArrowStackSpacer)
                projectTree.image(isSelected: selected == projectTree)
                Spacer().frame(width: ViewConstants.leafViewStackSpacer)
                Text(projectName(from: projectTree))
                    .lineLimit(1)
                    .foregroundStyle(selected == projectTree ? .revSelected : (projectTree.isCached ? .gray : .primary))
            }.frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: ViewConstants.verticalSpacer)
        }
        .background(selected == projectTree ? .selectBlue.opacity(ViewConstants.selectedColorAlpha) : .clear)
        .cornerRadius(ViewConstants.selectedCornerRadius)
    }
    
    private func projectName(from projectTree: ProjectTree) -> String {
        let count = projectTree.childrenCount
        return count == 0 ? projectTree.name : "\(projectTree.name) (\(count))"
    }
    
    private func findNext(for tree: ProjectTree, skipExtend: Bool = false) -> ProjectTree? {
        guard let parent = tree.parent, let children = parent.children else {
            return nil
        }
        
        for (i, child) in children.enumerated() {
            if child.name == tree.name {
                if expanded.contains(child) && !skipExtend {
                    return child.children?.first
                }
                if i == children.count - 1 {
                    return findNext(for: parent, skipExtend: true)
                }
                return children[i + 1]
            }
        }
        
        return nil
    }
    
    private func findPrev(for tree: ProjectTree) -> ProjectTree? {
        guard let parent = tree.parent, let children = parent.children else {
            return nil
        }
        
        for (i, child) in children.enumerated() {
            if child.name == tree.name {
                if i == 0 {
                    if parent.parent != nil {
                        return parent
                    }
                    return nil
                } else {
                    let prev = children[i - 1]
                    if expanded.contains(prev) {
                        return prev.children?.last
                    }
                    return prev
                }
            }
        }
        
        return nil
    }
}

fileprivate extension ProjectTree {
    func image(isSelected: Bool) -> AnyView {
        switch self.type {
        case .project:
            AnyView(
                Image.projectItem
                    .foregroundStyle(isSelected ? .revSelected : .project)
                    .fontWeight(.semibold)
            )
        case .target(let targetType):
            switch targetType {
            case .appExtension, .messagesExtension, .systemExtension, .extensionKitExtension:
                AnyView(
                    Image.extensionItem
                        .imageScale(.large)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .gray : .revSelected,
                                         isSelected ? .revSelected : .gray)
                )
            case .framework, .staticFramework:
                if isLocal {
                    AnyView(
                        Image.framework
                            .foregroundColor(isSelected ? .revSelected : .localFramework)
                    )
                } else {
                    AnyView(
                        Image.framework
                            .foregroundColor(isSelected ? .revSelected : .externalFramework)
                    )
                }
            case .bundle:
                AnyView(
                    Image.bundleItem
                        .foregroundColor(isSelected ? .revSelected : .bundle)
                )
            case .app:
                AnyView(
                    Image.applicationItem
                        .foregroundColor(isSelected ? .revSelected : .bundle)
                )
            case .staticLibrary, .dynamicLibrary:
                AnyView(
                    Image.libraryItem
                        .foregroundColor(isSelected ? .revSelected : .bundle)
                )
            case .unitTests, .uiTests:
                AnyView(
                    Image.testsItem
                        .foregroundStyle(isSelected ? .tests : .revSelected,
                                         isSelected ? .revSelected : .tests)
                )
            default:
                AnyView(
                    Image.unknownTargetType
                        .imageScale(.large)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .revSelected : .gray)
                )
            }
        }
    }
}
