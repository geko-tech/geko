import Foundation

protocol ISessionExporter {
    func clear()
    func export(_ path: String) -> Result<Void, Error>
}
