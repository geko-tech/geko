import Foundation

extension GekoS3 {

    // MARK: - Multiparts download

    public func getObjectMultiparts(
        _ object: String,
        bucket: String,
        filename: String
    ) async throws {
        let statObject = try await headObject(
            object,
            bucket: bucket
        )
        guard let fileSize = statObject.size else {
            throw GekoS3Error.invalideSize
        }
        let result: [Data]
        if fileSize > configuration.multipartChunkSize {
            result = try await downloadParts(
                object,
                bucket: bucket,
                concurancy: configuration.concurancyLimit,
                chunkSize: configuration.multipartChunkSize,
                fileSize: fileSize
            )
        } else {
            let data = try await getObject(object, bucket: bucket)
            result = [data]
        }
        try await writeFile(result, filename: filename)
    }

    // MARK: - Multiparts uploads

    public func putObjectMultiparts(
        _ object: String,
        bucket: String,
        filename: String,
        abortOnFail: Bool = true
    ) async throws {
        let fileURL = URL(fileURLWithPath: filename)
        let fileSize = try fileSize(fileURL: fileURL)
        if fileSize > configuration.multipartChunkSize {
            let uploadId = try await сreateMultipartUpload(object, bucket: bucket)
            do {
                let parts = try await uploadParts(
                    object,
                    bucket: bucket,
                    uploadId: uploadId,
                    fileURL: fileURL,
                    concurancy: configuration.concurancyLimit,
                    chunkSize: configuration.multipartChunkSize
                )
                try await completedMultipartUpload(
                    object,
                    bucket: bucket,
                    uploadId: uploadId,
                    parts: parts
                )
            } catch {
                guard abortOnFail else {
                    throw error
                }
                try await abortMultipartUpload(object, bucket: bucket, uploadId: uploadId)
                throw error
            }
        } else {
            let data = try Data(contentsOf: fileURL)
            try await putObject(
                object,
                bucket: bucket,
                data: data
            )
        }
    }

    // MARK: - Private

    private func uploadParts(
        _ object: String,
        bucket: String,
        uploadId: String,
        fileURL: URL,
        concurancy: Int,
        chunkSize: Int
    ) async throws -> [CompleteMultipartUpload.Part] {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }
        return try await withThrowingTaskGroup(of: (Int, String?).self) { group in
            var results = ContiguousArray<(Int, String?)>()
            for try await (index, chunk) in fileHandle.chunkEnumerated(ofCount: chunkSize) {
                if index > concurancy {
                    if let element = try await group.next() {
                        results.append(element)
                    }
                }
                group.addTask {
                    let partNumber = index + 1
                    let eTag = try await self.uploadPart(
                        object,
                        bucket: bucket,
                        uploadId: uploadId,
                        data: chunk,
                        partNumber: partNumber
                    )
                    return (partNumber, eTag)
                }
            }
            do {
                while let element = try await group.next() {
                    results.append(element)
                }
            } catch {
                throw GekoS3Error.multipartUpload(
                    error, results
                        .sorted(by: { $0.0 < $1.0 })
                        .map { CompleteMultipartUpload.Part(eTag: $1, partNumber: $0) }
                )
            }
            return results
                .sorted { $0.0 < $1.0 }
                .map { CompleteMultipartUpload.Part(eTag: $1, partNumber: $0) }
        }
    }

    private func downloadParts(
        _ object: String,
        bucket: String,
        concurancy: Int,
        chunkSize: Int,
        fileSize: Int
    ) async throws -> [Data] {
        let partsCount = Int(ceil(Double(fileSize) / Double(chunkSize)))
        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var results = ContiguousArray<(Int, Data)>()
            for index in 0..<partsCount {
                if index > concurancy {
                    if let element = try await group.next() {
                        results.append(element)
                    }
                }
                group.addTask {
                    let offset = index * chunkSize
                    let length = offset + chunkSize < fileSize ? chunkSize : nil
                    let data = try await self.getObject(
                        object,
                        bucket: bucket,
                        offset: offset,
                        length: length
                    )
                    return (index, data)
                }
            }
            while let element = try await group.next() {
                results.append(element)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    private func writeFile(
        _ parts: [Data],
        filename: String
    ) async throws {
        let fileURL = URL(fileURLWithPath: filename)
        if !FileManager.default.fileExists(atPath: filename) {
            _ = FileManager.default.createFile(atPath: filename, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        for part in parts {
            try handle.write(contentsOf: part)
        }
        try handle.close()
    }

    private func fileSize(
        fileURL: URL
    ) throws -> UInt64 {
        let handle = try FileHandle(forReadingFrom: fileURL)
        let size = handle.seekToEndOfFile()
        try handle.close()
        return size
    }
}

