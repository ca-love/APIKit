import Foundation

enum InputStreamError: Error {
    case invalidDataCapacity(Int)
    case unreadableStream(Error?)
}

extension Data {
    init(inputStream: InputStream, capacity: Int = Int(UInt16.max)) throws {
        var data = Data(capacity: capacity)

        let bufferSize = Swift.min(Int(UInt16.max), capacity)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        var readSize: Int

        repeat {
            readSize = inputStream.read(buffer, maxLength: bufferSize)

            switch readSize {
            case let x where x > 0:
                data.append(buffer, count: readSize)

            case let x where x < 0:
                throw InputStreamError.unreadableStream(inputStream.streamError)

            default:
                break
            }
        } while readSize > 0

        #if swift(>=4.1)
        buffer.deallocate()
        #else
        buffer.deallocate(capacity: bufferSize)
        #endif

        self.init(data)
    }
}
