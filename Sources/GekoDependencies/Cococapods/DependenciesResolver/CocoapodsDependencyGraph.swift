import Foundation
import GekoCocoapods

struct CocoapodsDependencyGraph {
    var specs: [(spec: CocoapodsSpec, version: CocoapodsVersion, subspecs: Set<String>, source: CocoapodsSource)]
}
