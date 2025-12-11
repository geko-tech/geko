import Foundation

extension FileHandle {

    @inlinable
    func chunkEnumerated(
        ofCount count: Int
    ) -> FileChunksEnumerated {
        FileChunksEnumerated(self, count: count)
    }
}

@usableFromInline
struct FileChunksEnumerated {
    @usableFromInline
    let handle: FileHandle
    @usableFromInline
    let count: Int

    @usableFromInline
    init(
        _ handle: FileHandle,
        count: Int
    ) {
        self.handle = handle
        self.count = count
    }
}


extension FileChunksEnumerated: AsyncSequence {
    @usableFromInline
    typealias Element = (Int, Data)

    @usableFromInline
    struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        let handle: FileHandle
        @usableFromInline
        let count: Int
        @usableFromInline
        var index: Int

        @usableFromInline
        init(
            _ handle: FileHandle,
            count: Int
        ) {
            self.handle = handle
            self.count = count
            self.index = 0
        }

        @inlinable
        mutating func next() async throws -> FileChunksEnumerated.Element? {
            let data = try handle.read(upToCount: count)
            if data?.count == 0 {
                return nil
            }
            let result = data.map { (index, $0) }
            self.index += 1
            return result
        }
    }

    @inlinable
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(handle, count: count)
    }
}
