extension String {
    public func contains(charArray: ContiguousArray<CChar>) -> Bool {
        utf8CString.containsCString(charArray)
    }
}
