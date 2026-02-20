import Foundation

public enum StdErrFilterError: FatalError {
    case errorOpeningStdErrStream

    public var description: String {
        switch self {
        case .errorOpeningStdErrStream:
            "Failed to open stream to read stderr"
        }
    }

    public var type: ErrorType {
        .abort
    }
}

public protocol StdErrFiltering: AnyObject {
    func filter<T>(
        isLineIncluded: @escaping (String) throws -> Bool,
        block: () throws -> T,
    ) async throws -> T
}

public final class StdErrFilter: StdErrFiltering {
    public init() {}

    public func filter<T>(
        isLineIncluded: @escaping (String) throws -> Bool,
        block: () throws -> T,
    ) async throws -> T {
        // Create a pipes
        // pipeFD[0] - for reading
        // pipeFD[1] - for writing
        var pipeFds: [Int32] = [-1, -1]
        let pipeResult = pipe(&pipeFds)

        guard pipeResult == 0 else {
            return try block()
        }

        let pipeRead = pipeFds[0]
        let pipeWrite = pipeFds[1]

        // Save the current stderr
        let originalStderr = dup(STDERR_FILENO)

        // Replace stderr. Now everything written to errors goes into our pipe
        fflush(stderr)
        dup2(pipeWrite, STDERR_FILENO)

        let readerTask = Task.detached(priority: .high) {
            // Convert the read handle (Int32) into a file pointer (FILE*)
            guard let readStream = fdopen(pipeRead, "r") else {
                throw StdErrFilterError.errorOpeningStdErrStream
            }

            // Variables for getline
            var linePtr: UnsafeMutablePointer<CChar>? = nil
            var lineCap: Int = 0

            while true {
                // getline automatically allocates memory (realloc) in linePtr
                let bytesRead = getline(&linePtr, &lineCap, readStream)

                if bytesRead == -1 {
                    break // End of data (EOF) or error
                }

                if let linePtr = linePtr {
                    let line = String(cString: linePtr)
                    if try isLineIncluded(line) {
                        line.withCString { ptr in
                            _ = write(originalStderr, ptr, Int(strlen(ptr)))
                        }
                    }
                }
            }

            // Clearing memory (getline uses malloc internally, so you need to free it)
            if let linePtr {
                free(linePtr)
            }
            // Close the reading stream
            fclose(readStream)
            close(pipeRead)
        }

        // Perform block
        let result = try block()

        // Restoring normal stderr (to see errors further)
        fflush(stderr)
        dup2(originalStderr, STDERR_FILENO)

        // Close the write end to signal the reader to finish
        close(pipeWrite)

        // Wait for the reader to finish processing any remaining data
        try await readerTask.value

        return result
    }
}
