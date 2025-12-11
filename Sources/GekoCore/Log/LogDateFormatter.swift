import Foundation

public protocol LogDateFormatting {
    func dateToString(_ date: Date) -> String
    func stringToDate(_ date: String) -> Date?
}

public final class LogDateFormatter: LogDateFormatting {
    // MARK: - Attributes

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy'T'HH.mm.ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        return dateFormatter
    }()

    // MARK: - Init

    public init() {}

    // MARK: - LogDateFormatting

    public func dateToString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    public func stringToDate(_ date: String) -> Date? {
        dateFormatter.date(from: date)
    }
}
