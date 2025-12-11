import ProjectDescription
import GekoWorkspaceMapperFixture

let workspace = Workspace(
    name: "GekoWorkspaceMapperTest",
    projects: [
        "./"
    ],
    workspaceMappers: [
        WorkspaceMapper(
            name: "GekoWorkspaceMapperFixture",
            params: [
                Constants.parameterName: GekoWorkspaceMapperFixture.SomeStruct(
                    name: "name",
                    items: [
                        .generate(name: "name1", str: "str1", count: 2),
                        .generate(name: "name2", str: "str2", boolValue: true),
                    ]
                ).toJSONString()
            ]
        )
    ]
)
