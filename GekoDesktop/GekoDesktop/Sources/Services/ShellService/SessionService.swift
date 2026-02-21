import Combine
import Foundation
import TSCBasic
import TSCUtility

enum SessionServiceError: FatalError {
    case terminated(command: String, code: Int32, standardError: Data)
    case signalled(command: String, code: Int32, standardError: Data)
    case canNotCreateInputFile
    case shellVariableIsEmpty
    case generationError(info: String)
    
    var errorDescription: String? {
        switch self {
        case let .signalled(command, code, data):
            if data.count > 0, let string = String(data: data, encoding: .utf8) {
                return "The '\(command)' was interrupted with a signal \(code) and message:\r\n\(string)\r\n"
            } else {
                return "The '\(command)' was interrupted with a signal \(code)\r\n"
            }
        case let .terminated(command, code, data):
            if data.count > 0, let string = String(data: data, encoding: .utf8) {
                return "The '\(command)' command exited with error code \(code) and message:\r\n\(string)\r\n"
            } else {
                return "The '\(command)' command exited with error code \(code)\r\n"
            }
        case .canNotCreateInputFile:
            return "Couldn't create input file from input data.\r\n"
        case .shellVariableIsEmpty:
            return "Shell environment variable is empty.\r\n"
        case .generationError(let info):
            return info
        }
    }
    
    var type: FatalErrorType {
        return .abort
    }
}

enum ResponseTypeError: FatalError {
    case wrongType
    
    var errorDescription: String? {
        switch self {
        case .wrongType:
            "Wrong response type"
        }
    }
    
    var type: FatalErrorType {
        .abort
    }
}

protocol ISessionServiceDelegate: AnyObject {
    func output(_ str: String)
    func sessionDidReset()
}

protocol ISessionService {
    func addSubscription(_ subscription: some ISessionServiceDelegate)

    @discardableResult
    func exec(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult
    func lastFailedCommands() -> [String]
    func clearSession()
}

extension ISessionService {
    @discardableResult
    func exec(_ command: String) throws -> String {
        switch try exec(ShellCommand(arguments: [command])) {
        case .collected(let data):
            if let str = String(data: data, encoding: .utf8) {
                return str
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Corrupted data"))
            }
        default:
            throw ResponseTypeError.wrongType
        }
    }
}

final class SessionService: ISessionService {
    
    private var subscritpions = DelegatesList<ISessionServiceDelegate>()
    private var executioningCommands: [String] = []
    private let lock: NSLocking = NSRecursiveLock()
    private var errorData: Data = Data()
    private let logger: ILogger
    
    init(logger: ILogger) {
        self.logger = logger
    }
    
    func addSubscription(_ subscription: some ISessionServiceDelegate) {
        subscritpions.addDelegate(weakify(subscription))
    }
    
    func exec(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult {
        if command.logInput {
            output("user: \(command.arguments.joined(separator: " "))")
        }
        do {
            switch command.resultType {
            case .collected:
                return try buildCollected(command)
            case .stream:
                return try buildStream(command)
            case .void:
                return try buildVoid(command)
            }
        } catch {
            logger.log(.error, info: error.localizedDescription)
            throw error
        }
    }
    
    func lastFailedCommands() -> [String] {
        defer { lock.unlock() }
        lock.lock()
        return executioningCommands
    }
    
    func clearSession() {
        subscritpions.makeIterator().forEach { $0.sessionDidReset() }
    }
}

private extension SessionService {
    func buildCollected(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult {
        guard let input = command.inputFile else {
            return try capture(command)
        }
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let process = SessionService.process(
            try currentShell(),
            command.arguments,
            environment: buildEnvVariables()
        )
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        let inputFilePath = "\(FileManager.default.temporaryDirectory.path()).~input.temp"
        let inputFile = try inputFileForInput(input, atPath: inputFilePath)
        process.standardInput = inputFile

        var result = Data()
        var error = Data()

        let group = DispatchGroup()
        group.enter()
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                result.append(data)
            }
        }
        
        group.enter()
        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                errorPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                error.append(data)
            }
        }

        try process.run()
        process.waitUntilExit()
        group.wait()
        
        deleteInputFile(inputFile, atPath: inputFilePath)
        
        if !error.isEmpty && process.terminationStatus != 0 {
            output(error)
            setLastFailedCommands(command.arguments)
            throw SessionServiceError.terminated(command: command.arguments.first!, code: process.terminationStatus, standardError: error)
        }
        if !command.silence {
            output(result)
        }

        return .collected(result)
    }
    
    func capture(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult {
        let process = Process(
            arguments: [try currentShell(), "-l", "-i" ,"-c", command.arguments.joined(separator: " ")],
            environment: buildEnvVariables(),
            outputRedirection: .collect,
            startNewProcessGroup: false
        )
        
        try process.launch()
        let result = try process.waitUntilExit()
        do {
            switch result.exitStatus {
            case .terminated(let code):
                if code == 0 {
                    let output = try result.utf8Output()
                    return .collected(output.data(using: .utf8)!) 
                }
                let errorOutput = try result.utf8stderrOutput()
                throw SessionServiceError.terminated(command: command.arguments.joined(separator: " "), code: code, standardError: errorOutput.data(using: .utf8)!)
            case .signalled(let signal):
                let errorOutput = try result.utf8stderrOutput()
                throw SessionServiceError.signalled(command: command.arguments.joined(separator: " "), code: signal, standardError: errorOutput.data(using: .utf8)!)
            }
            
        } catch {
            setLastFailedCommands(command.arguments)
            throw error
        }
    }
    
    func buildVoid(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult {
        let input = [try currentShell(), "-l", "-i" ,"-c", command.arguments.joined(separator: " ")]
        let process = Process(
            arguments: input,
            environment: buildEnvVariables(),
            outputRedirection: .collect,
            startNewProcessGroup: false
        )
        let cancel = AnyCancellable { [weak self] in
            if !command.silence {
                self?.output("\(command.arguments.joined(separator: " ")) killed")
            }
            process.signal(9) // SIGKILL
        }
        try process.launch()
        return .void(cancel)
    }
    
    func buildStream(_ command: ShellCommand) throws -> ShellCommand.ShellCommandResult {
        return .stream(publisher(command.arguments, verbose: !command.silence, environment: buildEnvVariables()))
    }
    
    func setLastFailedCommands(_ commands: [String]) {
        lock.lock()
        executioningCommands = commands
        lock.unlock()
    }
}

// MARK: - Output

private extension SessionService {
    func output(_ data: Data) {
        guard let str = String(data: data, encoding: .utf8) else {
            output("Data decoding error")
            return
        }
        output(str)
    }
    
    func output(_ str: String) {
        print(str)
        var tmpStr = str
        if tmpStr.contains(eraseLineSymbol) {
            tmpStr.replace(eraseLineSymbol, with: "\n")
            tmpStr.replace("\n", with: "\r\n")
        } else {
            tmpStr = tmpStr.replacingOccurrences(of: "\r", with: "")
            tmpStr = tmpStr.replacingOccurrences(of: "\n", with: "")
            if tmpStr.contains("𓆌") || tmpStr.contains("𓆊") {
                tmpStr.append("\r")
            } else {
                tmpStr.append("\r\n")
            }
        }
        subscritpions.forEach { $0.output(tmpStr) }
    }
    
    var eraseLineSymbol: String {
        "\u{1B}[2K\r"
    }
}

// MARK: - Helpers

private extension SessionService {
    func currentShell() throws -> String {
        guard let shell = ProcessInfo.processInfo.environment["SHELL"] else {
            throw SessionServiceError.shellVariableIsEmpty
        }
        return shell
    }
    
    func buildEnvVariables() -> [String: String] {
        var env: [String: String] = ["LC_CTYPE": "UTF-8"]
        env["SHELL"] = try! currentShell()
        env["GEKO_CONFIG_COLOURED_OUTPUT"] = "YES"
        return env
    }
    
    func deleteInputFile(_ fileHandle: FileHandle, atPath filePath: String) {
        fileHandle.closeFile()
        try? FileManager.default.removeItem(atPath: filePath)
    }

    func inputFileForInput(_ input: String, atPath inputFilePath: String) throws -> FileHandle {
        if FileManager.default.fileExists(atPath: inputFilePath) {
            try FileManager.default.removeItem(atPath: inputFilePath)
        }
        guard FileManager.default.createFile(atPath: inputFilePath, contents: nil),
              let inputData = input.data(using: .ascii),
              let inputFile = FileHandle(forUpdatingAtPath: inputFilePath)
        else {
            throw SessionServiceError.canNotCreateInputFile
        }

        try inputFile.seekToEnd()
        try inputFile.write(contentsOf: inputData)
        try inputFile.seek(toOffset: 0)
        return inputFile
    }
}

// MARK: - Static Helpers

private extension SessionService {
    /// Converts an array of arguments into a `Foundation.Process`
    /// - Parameters:
    ///   - shellPath: Executable URL.
    ///   - arguments: Arguments for the process.
    ///   - environment: Environment
    /// - Returns: A `Foundation.Process`

    static func process(
        _ shell: String,
        _ arguments: [String],
        environment: [String: String]
    ) -> Foundation.Process {
        let executablePath = shell
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = Array(arguments)
        process.environment = environment
        return process
    }
}

// MARK: - Publisher

private extension SessionService {
    func publisher(
        _ arguments: [String],
        verbose: Bool,
        environment: [String: String]
    ) -> AnyPublisher<SystemEvent<Data>, Error> {
        return .create { [weak self] subscriber in

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            self?.errorData = Data()

            do {
                process.launchPath = try self?.currentShell()
            } catch {
                subscriber.send(completion: .failure(error))
            }
            
            process.arguments = ["-l", "-i", "-c", arguments.joined(separator: " ")]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.environment = environment

            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading

            let outputQueue = DispatchQueue(label: "outputQueue", qos: .userInitiated)
            let errorQueue = DispatchQueue(label: "errorQueue", qos: .userInitiated)

            outputHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputQueue.async {
                    self?.output(data)
                }
            }

            errorHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                errorQueue.async {
                    self?.errorData.append(data)
                    self?.output(data)
                }
            }
            
            DispatchQueue.global().async { [weak self] in
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    self?.setLastFailedCommands(arguments)
                    subscriber.send(completion: .failure(error))
                }

                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                
                Task {
                    if let data = self?.errorData, !data.isEmpty, let errorInfo = String(data: data, encoding: .utf8) {
                        self?.logger.log(.error, info: errorInfo, additionalInfo: ["Commands": arguments.joined(separator: "\r\n")])
                    }
                }
                subscriber.send(completion: .finished)
            }
            return AnyCancellable {
                process.interrupt()
            }
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate extension AnyPublisher {
    /// Create a publisher which accepts a closure with a subscriber argument,
    /// to which you can dynamically send value or completion events.
    ///
    /// You should return a `Cancelable`-conforming object from the closure in
    /// which you can define any cleanup actions to execute when the pubilsher
    /// completes or the subscription to the publisher is canceled.
    ///
    /// - parameter factory: A factory with a closure to which you can
    ///                      dynamically send value or completion events.
    ///                      You should return a `Cancelable`-conforming object
    ///                      from it to encapsulate any cleanup-logic for your work.
    ///
    /// An example usage could look as follows:
    ///
    ///    ```
    ///    AnyPublisher<String, MyError>.create { subscriber in
    ///        // Values
    ///        subscriber.send("Hello")
    ///        subscriber.send("World!")
    ///
    ///        // Complete with error
    ///        subscriber.send(completion: .failure(MyError.someError))
    ///
    ///        // Or, complete successfully
    ///        subscriber.send(completion: .finished)
    ///
    ///        return AnyCancellable {
    ///          // Perform clean-up
    ///        }
    ///    }
    ///
    init(_ factory: @escaping Publishers.Create<Output, Failure>.SubscriberHandler) {
        self = Publishers.Create(factory: factory).eraseToAnyPublisher()
    }

    /// Create a publisher which accepts a closure with a subscriber argument,
    /// to which you can dynamically send value or completion events.
    ///
    /// You should return a `Cancelable`-conforming object from the closure in
    /// which you can define any cleanup actions to execute when the pubilsher
    /// completes or the subscription to the publisher is canceled.
    ///
    /// - parameter factory: A factory with a closure to which you can
    ///                      dynamically send value or completion events.
    ///                      You should return a `Cancelable`-conforming object
    ///                      from it to encapsulate any cleanup-logic for your work.
    ///
    /// An example usage could look as follows:
    ///
    ///    ```
    ///    AnyPublisher<String, MyError>.create { subscriber in
    ///        // Values
    ///        subscriber.send("Hello")
    ///        subscriber.send("World!")
    ///
    ///        // Complete with error
    ///        subscriber.send(completion: .failure(MyError.someError))
    ///
    ///        // Or, complete successfully
    ///        subscriber.send(completion: .finished)
    ///
    ///        return AnyCancellable {
    ///          // Perform clean-up
    ///        }
    ///    }
    ///
    static func create(_ factory: @escaping Publishers.Create<Output, Failure>.SubscriberHandler)
        -> AnyPublisher<Output, Failure> {
        AnyPublisher(factory)
    }
}

// MARK: - Publisher
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate extension Publishers {
    /// A publisher which accepts a closure with a subscriber argument,
    /// to which you can dynamically send value or completion events.
    ///
    /// You should return a `Cancelable`-conforming object from the closure in
    /// which you can define any cleanup actions to execute when the pubilsher
    /// completes or the subscription to the publisher is canceled.
    struct Create<Output, Failure: Swift.Error>: Publisher {
        public typealias SubscriberHandler = (Subscriber) -> Cancellable
        private let factory: SubscriberHandler

        /// Initialize the publisher with a provided factory
        ///
        /// - parameter factory: A factory with a closure to which you can
        ///                      dynamically push value or completion events
        public init(factory: @escaping SubscriberHandler) {
            self.factory = factory
        }

        public func receive<S: Combine.Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(factory: factory, downstream: subscriber))
        }
    }
}

// MARK: - Subscription
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension Publishers.Create {
    class Subscription<Downstream: Combine.Subscriber>: Combine.Subscription where Output == Downstream.Input, Failure == Downstream.Failure {
        private let buffer: DemandBuffer<Downstream>
        private var cancelable: Cancellable?

        init(factory: @escaping SubscriberHandler,
             downstream: Downstream) {
            self.buffer = DemandBuffer(subscriber: downstream)

            let subscriber = Subscriber(onValue: { [weak self] in _ = self?.buffer.buffer(value: $0) },
                                        onCompletion: { [weak self] in self?.buffer.complete(completion: $0) })

            self.cancelable = factory(subscriber)
        }

        func request(_ demand: Subscribers.Demand) {
            _ = self.buffer.demand(demand)
        }

        func cancel() {
            self.cancelable?.cancel()
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publishers.Create.Subscription: CustomStringConvertible {
    var description: String {
        return "Create.Subscription<\(Output.self), \(Failure.self)>"
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate extension Publishers.Create {
    struct Subscriber {
        private let onValue: (Output) -> Void
        private let onCompletion: (Subscribers.Completion<Failure>) -> Void

        fileprivate init(onValue: @escaping (Output) -> Void,
                         onCompletion: @escaping (Subscribers.Completion<Failure>) -> Void) {
            self.onValue = onValue
            self.onCompletion = onCompletion
        }

        /// Sends a value to the subscriber.
        ///
        /// - Parameter value: The value to send.
        public func send(_ input: Output) {
            onValue(input)
        }

        /// Sends a completion event to the subscriber.
        ///
        /// - Parameter completion: A `Completion` instance which indicates whether publishing has finished normally or failed with an error.
        public func send(completion: Subscribers.Completion<Failure>) {
            onCompletion(completion)
        }
    }
}
