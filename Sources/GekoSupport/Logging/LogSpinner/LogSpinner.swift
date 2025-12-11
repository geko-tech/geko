import Foundation

struct StdOutSpinnerStream: SpinnerStream {
    func write(string: String, terminator: String) {
        print(string, terminator: terminator)
        fflush(stdout)
    }

    func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
        fflush(stdout)
    }

    func showCursor() {
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }
}

struct DefaultSpinnerSignal {
    func trap() {
        SignalHandler().trap { _ in
            print("\u{001B}[?25h", terminator: "")
            exit(0)
        }
    }
}

public final class LogSpinner {
    // MARK: - Attributes

    private let format = "{S} {T}"
    private let queue = DispatchQueue(label: "io.geko.spinner\(UUID().uuidString)")
    private let speed: Double
    private let stream: SpinnerStream
    private let ciChecker: CIChecking

    private var message: String
    private var status: Bool
    private var frameIndex: Int
    private var animation: SpinnerAnimation {
        didSet {
            frameIndex = 0
        }
    }

    // MARK: - Initialization

    public init(
        message: String = "",
        animation: SpinnerAnimation = .geko,
        speed: Double? = nil
    ) {
        self.animation = animation
        self.message = message
        self.speed = speed ?? animation.defaultSpeed
        self.stream = StdOutSpinnerStream()
        self.ciChecker = CIChecker()
        self.status = false
        self.frameIndex = 0

        DefaultSpinnerSignal().trap()
    }

    // MARK: - LogSpinner

    public func start(message: String = "") {
        self.message = message
        guard !ciChecker.isCI() && !isDebug else {
            logger.notice(.init(stringLiteral: message))
            return
        }
        
        stream.hideCursor()
        status = true
        queue.async { [weak self] in
            guard let `self` else { return }
            while self.status {
                self.render()
                usleep(useconds_t(self.speed * 1_000_000))
            }
        }
    }

    public func stop() {
        guard !ciChecker.isCI() && !isDebug else { return }
        status = false
        render()
        stream.write(string: "", terminator: "\n")
        stream.showCursor()
    }

    // MARK: - Private

    private func frame() -> String {
        let frame = animation.frames[frameIndex]
        frameIndex = (frameIndex + 1) % animation.frames.count
        return frame
    }

    private func render() {
        let spinner = format
            .replacingOccurrences(of: "{S}", with: frame())
            .replacingOccurrences(of: "{T}", with: message)

        stream.write(string: "\r", terminator: "")
        stream.write(string: spinner, terminator: "")
    }
    
    private var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
