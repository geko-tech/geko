public protocol SpinnerStream {
    func write(string: String, terminator: String)
    func hideCursor()
    func showCursor()
}
