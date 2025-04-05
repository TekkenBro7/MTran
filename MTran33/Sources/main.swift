import CDispatch
import Foundation

func main() {
    let logFileName = Logger.logFileName
    if FileManager.default.fileExists(atPath: logFileName) {
        try? "".write(to: URL(fileURLWithPath: logFileName), atomically: true, encoding: .utf8)
    }
    let logFileName2 = Logger2.logFileName
    if FileManager.default.fileExists(atPath: logFileName2) {
        try? "".write(to: URL(fileURLWithPath: logFileName2), atomically: true, encoding: .utf8)
    }

    let inputFileName = "TestLexer.txt"
    guard let sourceCode = try? String(contentsOfFile: inputFileName, encoding: .utf8) else {
        print("Ошибка: нельзя открыть файл \(inputFileName)")
        return
    }

    let outputFileNameTable = "outputTable.txt"
    // Очищаем файл перед запуском
    if FileManager.default.fileExists(atPath: outputFileNameTable) {
        try? "".write(toFile: outputFileNameTable, atomically: true, encoding: .utf8)
    } else {
        FileManager.default.createFile(atPath: outputFileNameTable, contents: nil, attributes: nil)
    }

    Logger.log("Запуск лексического анализа файла \(inputFileName)")
    let lexer = Lexer(source: sourceCode)
    let tokens = lexer.tokenize()
    if tokens.isEmpty {
        print("Нет токенов")
    } else {
        // for token in tokens {
        //     let outputLine =
        //         "Токен: \(token.type.rawValue) Лексема: \"\(token.value)\" Строка: \(token.line) Id: \(token.id)"
        //     Logger.log(outputLine)
        //     print(outputLine)
        // }
        
        // Группируем токены по их типу
        let groupedTokens = Dictionary(grouping: tokens, by: { $0.type })

        // Открываем файл для записи
        if let outputFile = FileHandle(forWritingAtPath: outputFileNameTable) {
            var printedLexemes = Set<String>()
            for (type, tokens) in groupedTokens {
                let header = "\n=== \(type) TOKENS ===\n"
                outputFile.write(header.data(using: .utf8)!)

                let tableHeader = """
                    +-----------------------+--------+-------+
                    | Лексема               | Строка | ID    |
                    +-----------------------+--------+-------+
                    """
                Logger.log(tableHeader)
                outputFile.write(tableHeader.data(using: .utf8)!)
                outputFile.write("\n".data(using: .utf8)!)

                for token in tokens {
                    let lexeme = token.value

                    let lines = stride(from: 0, to: lexeme.count, by: 21).map {
                        String(lexeme.dropFirst($0).prefix(21))
                    }
                    for (index, part) in lines.enumerated() {
                        let formattedLexeme = part.padding(toLength: 21, withPad: " ", startingAt: 0)
                        let row: String
                        if index == 0 {
                            // Первая строка с номером строки и ID
                            row = String(format: "| %@ | %-6d | %-5d |\n", formattedLexeme, token.line, token.id)
                        } else {
                            // Последующие строки без номера строки и ID
                            row = String(format: "| %@ |        |       |\n", formattedLexeme)
                        }
                        Logger.log(row)
                        outputFile.write(row.data(using: .utf8)!)
                    }
                }
                let tableFooter = "+-----------------------+--------+-------+\n"
                outputFile.write(tableFooter.data(using: .utf8)!)
                Logger.log(tableFooter)
            }
            print("Таблицы токенов записаны в \(outputFileNameTable)")
            outputFile.closeFile()
        } else {
            print("Ошибка: нельзя открыть файл для вывода")
        }
    }


    let outputFileName = "output.txt"
        if FileManager.default.fileExists(atPath: outputFileName) {
            try? "".write(toFile: outputFileName, atomically: true, encoding: .utf8)
        } else {
            let fileCreated = FileManager.default.createFile(atPath: outputFileName, contents: nil, attributes: nil)
            if !fileCreated {
                print("Ошибка: Не удалось создать файл.")
            }
        }
    if let outputFile = FileHandle(forWritingAtPath: outputFileName) {
            var printedLexemes = Set<String>()
            for token in tokens {
                let outputLine =
                    "Токен: \(token.type.rawValue) Лексема: @\(token.value)@ Строка: \(token.line) Id: \(token.id) Отступ: \(token.indentationLevel)\n"
                outputFile.write(outputLine.data(using: .utf8)!)
            }
        print("Токены записаны в \(outputFileName)")
        outputFile.closeFile()
    } else {
        print("Ошибка: нельзя открыть файл для вывода")
    }
    
    do {
        let parser = Parser(tokens: tokens)
        try parser.validateTokens() 

        let astRoot = parser.parseProgram()

        astRoot.printTree()
        writeTreeToFile(astRoot, fileName: "tree.txt")

        // Семантический анализ
        let analyzer = SemanticAnalyzer()
        let errors = analyzer.analyze(node: astRoot)
        
        if !errors.isEmpty {
            print("\nСемантические ошибки:\n")
            for error in errors {
                print(error)
            }
            print("\nСемантический анализ завершен успешно")
        } else {
            print("\nСемантический анализ завершен успешно")
        }

    } catch let error as ParseError {
        print("ОШИБКА: \(error.description)")
        exit(1)
    } catch {
        print("Неизвестная ошибка: \(error)")
        exit(1)
    }
}

main()
