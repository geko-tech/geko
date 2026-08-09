import XCTest
@testable import GekoDesktop

final class TerminalOutputTests: XCTestCase {
    func test_usesVerticalOverlayScroller() throws {
        let terminalView = makeTerminalView()
        terminalView.layoutSubtreeIfNeeded()

        let scroller = try XCTUnwrap(terminalView.subviews.compactMap { $0 as? NSScroller }.first)
        XCTAssertEqual(scroller.scrollerStyle, .overlay)
        XCTAssertGreaterThan(scroller.frame.height, scroller.frame.width)
        XCTAssertEqual(scroller.frame.maxX, terminalView.bounds.maxX, accuracy: 0.5)
        XCTAssertTrue(scroller.isHidden)

        terminalView.feed(byteArray: Array(String(repeating: "line\n", count: 1_000).utf8)[...])

        XCTAssertFalse(scroller.isHidden)
    }

    func test_preservesWhitespaceChunkBoundariesAndMissingTrailingNewline() {
        let terminalView = makeTerminalView()
        let chunks = [
            "first line\n  nested    value\n\npart",
            "ial",
        ]

        chunks.forEach { terminalView.feed(byteArray: Array($0.utf8)[...]) }

        XCTAssertEqual(line(0, in: terminalView), "first line")
        XCTAssertEqual(line(1, in: terminalView), "  nested    value")
        XCTAssertEqual(line(2, in: terminalView), "")
        XCTAssertEqual(line(3, in: terminalView), "partial")
    }

    func test_handlesCRLFAndCarriageReturnProgressUpdates() {
        let terminalView = makeTerminalView()

        terminalView.feed(byteArray: Array("windows\r\nProgress 10%\r\u{001B}[2KProgress 100%".utf8)[...])

        XCTAssertEqual(line(0, in: terminalView), "windows")
        XCTAssertEqual(line(1, in: terminalView), "Progress 100%")
    }

    func test_handlesANSISequencesSplitAcrossChunks() {
        let terminalView = makeTerminalView()

        ["\u{001B}[1;3", "1mred", "\u{001B}[0m plain"].forEach {
            terminalView.feed(byteArray: Array($0.utf8)[...])
        }

        XCTAssertEqual(line(0, in: terminalView), "red plain")
        XCTAssertTrue(terminalView.getTerminal().getCharData(col: 0, row: 0)?.attribute.style.contains(.bold) == true)
        XCTAssertEqual(terminalView.getTerminal().getCharData(col: 0, row: 0)?.attribute.fg, .ansi256(code: 1))
        XCTAssertEqual(terminalView.getTerminal().getCharData(col: 4, row: 0)?.attribute.style, CharacterStyle.none)
        XCTAssertEqual(terminalView.getTerminal().getCharData(col: 4, row: 0)?.attribute.fg, .defaultColor)
    }

    func test_handlesUTF8ScalarSplitAcrossChunks() {
        let terminalView = makeTerminalView()
        let bytes = Array("🐊".utf8)

        terminalView.feed(byteArray: bytes[0 ..< 2])
        terminalView.feed(byteArray: bytes[2...])

        XCTAssertEqual(line(0, in: terminalView), "🐊")
    }

    func test_preservesMixedOutputChunksInDeliveryOrder() {
        let terminalView = makeTerminalView()
        let stdout = "stdout 1\n"
        let stderr = "  stderr\n"
        let finalStdout = "stdout 2"

        [stdout, stderr, finalStdout].forEach {
            terminalView.feed(byteArray: Array($0.utf8)[...])
        }

        XCTAssertEqual(line(0, in: terminalView), "stdout 1")
        XCTAssertEqual(line(1, in: terminalView), "  stderr")
        XCTAssertEqual(line(2, in: terminalView), "stdout 2")
    }

    func test_wrapsLongLinesWithoutChangingTheirContents() {
        let terminalView = makeTerminalView()
        let text = String(repeating: "0123456789", count: 50)

        terminalView.feed(byteArray: Array(text.utf8)[...])

        let terminal = terminalView.getTerminal()
        let renderedText = (0 ... terminal.buffer.y).map {
            terminal.buffer.translateBufferLineToString(lineIndex: $0, trimRight: true)
        }.joined()
        XCTAssertEqual(renderedText, text)
    }

    func test_handlesLargeRapidOutput() {
        let terminalView = makeTerminalView()
        let output = (0 ..< 2_000).map { "line \($0)\n" }.joined()

        terminalView.feed(byteArray: Array(output.utf8)[...])

        XCTAssertEqual(
            terminalView.getTerminal().buffer.translateBufferLineToString(
                lineIndex: terminalView.getTerminal().buffer.lines.count - 2,
                trimRight: true
            ),
            "line 1999"
        )
    }

    private func line(_ index: Int, in terminalView: TerminalView) -> String {
        terminalView.getTerminal().buffer.translateBufferLineToString(
            lineIndex: index,
            trimRight: true
        )
    }

    private func makeTerminalView() -> TerminalView {
        let terminalView = TerminalView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 800), font: nil)
        terminalView.getTerminal().options.convertEol = true
        terminalView.getTerminal().resetToInitialState()
        return terminalView
    }
}
