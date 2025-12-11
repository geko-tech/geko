import ProjectDescription

extension WorkspaceWithProjects {
    public mutating func concurrentResolveGlobs(checkFilesExist: Bool) throws {
        self.projects = try self.projects.map(context: .concurrent) { project in
            var project = project
            try project.resolveGlobs(checkFilesExist: checkFilesExist)
            return project
        }
    }
}
