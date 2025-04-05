import CDispatch
import Foundation

class Logger {
    static let logFileName = "log.txt"

    static func log(_ message: String) {
        let logMessage = "\(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileName) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFileName))
                {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFileName))
            }
        }
    }
}

class Logger2 {
    static let logFileName = "log2.txt"

    static func log(_ message: String) {
        let logMessage = "\(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileName) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFileName))
                {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFileName))
            }
        }
    }
}

func writeTreeToFile(_ root: ASTNode, fileName: String) {
    if FileManager.default.fileExists(atPath: fileName) {
        try? "".write(toFile: fileName, atomically: true, encoding: .utf8)
    } else {
        FileManager.default.createFile(atPath: fileName, contents: nil, attributes: nil)
    }
    if let fileHandle = FileHandle(forWritingAtPath: fileName) {
        root.writeTreeToFile(fileHandle)
        fileHandle.closeFile()
    } else {
        print("Ошибка: нельзя открыть файл для записи")
    }
}