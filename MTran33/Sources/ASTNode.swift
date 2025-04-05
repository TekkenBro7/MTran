import CDispatch
import Foundation

class ASTNode {
    let type: String
    let value: String
    let line: Int
    var children: [ASTNode]

    init(type: String, value: String = "", line: Int = 1) {
        self.type = type
        self.value = value
        self.line = line
        self.children = []
    }

    func addChild(_ child: ASTNode) {
        children.append(child)
    }

    func printTree(prefix: String = "", isLast: Bool = true) {
        print(prefix + (isLast ? "└── " : "├── ") + type + (value.isEmpty ? "" : ": " + value))
        for (index, child) in children.enumerated() {
            child.printTree(
                prefix: prefix + (isLast ? "    " : "│   "), isLast: index == children.count - 1)
        }
    }

    func writeTreeToFile(_ fileHandle: FileHandle, prefix: String = "", isLast: Bool = true) {
        let line =
            prefix + (isLast ? "└── " : "├── ") + type + (value.isEmpty ? "" : ": " + value) + "\n"
        if let data = line.data(using: .utf8) {
            fileHandle.write(data)
        }
        for (index, child) in children.enumerated() {
            child.writeTreeToFile(
                fileHandle, prefix: prefix + (isLast ? "    " : "│   "),
                isLast: index == children.count - 1)
        }
    }
}
