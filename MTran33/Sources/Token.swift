import CDispatch
import Foundation

// Типы токенов
enum TokenType: String {
    case keyword = "KEYWORD"
    case identifier = "IDENTIFIER"
    case number = "NUMBER"
    case floatNumber = "FLOAT_NUMBER"
    case stringLiteral = "STRING_LITERAL"
    case charLiteral = "CHAR_LITERAL"
    case operatorToken = "OPERATOR"
    case attribute = "ATTRIBUTE"
    case error = "ERROR"
}

// Структура токена
struct Token {
    let type: TokenType
    let value: String
    let line: Int
    let id: Int
    let indentationLevel: Int
}

// Чтение токенов из файла
func readTokens(from filePath: String) -> [Token] {
    var tokens: [Token] = []

    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        print("Ошибка: не удалось открыть файл \(filePath)")
        return tokens
    }

    let lines = content.components(separatedBy: "\n")
    for line in lines where !line.isEmpty {
        var components = line.components(separatedBy: " ")
        guard components.count >= 9 else { continue }

        let typeString = components[1]

        // Определяем начало и конец строки для STRING_LITERAL
        if typeString == "STRING_LITERAL" {
            // Ищем индекс начала и конца строки в кавычках @"..."
            guard let startRange = line.range(of: "@\""),
                let endRange = line.range(of: "\"@", options: .backwards)
            else { continue }

            // Извлекаем корректную строку
            let lexeme = String(line[startRange.upperBound..<endRange.lowerBound])

            let lineNumber = Int(components[5]) ?? 0
            let id = Int(components[7]) ?? 0
            let indentation = Int(components[9]) ?? 0

            let type = TokenType(rawValue: typeString) ?? .error
            tokens.append(
                Token(
                    type: type, value: lexeme, line: lineNumber, id: id,
                    indentationLevel: indentation))
        } else {
            // Обычная обработка, если не строковый литерал
            let lexeme = components[3].trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            let lineNumber = Int(components[5]) ?? 0
            let id = Int(components[7]) ?? 0
            let indentation = Int(components[9]) ?? 0

            let type = TokenType(rawValue: typeString) ?? .error
            tokens.append(
                Token(
                    type: type, value: lexeme, line: lineNumber, id: id,
                    indentationLevel: indentation))
        }
    }
    return tokens
}

// Ключевые слова F#
let fsharpKeywords: Set<String> = [
    "let", "rec", "fun", "match", "with", "if", "then", "else", "elif", "for", "to", "do", "while",
    "type", "module", "namespace", "open", "exception", "try", "finally", "raise", "begin", "end",
    "in", "of", "when", "as", "val", "mutable", "lazy", "async", "yield", "return", "use", "new",
    "interface", "inherit", "abstract", "default", "member", "static", "override", "private",
    "public", "internal", "base", "null", "true", "false", "and", "or", "not", "upcast", "downcast",
    "int", "int32", "int64", "float", "double", "decimal", "bool", "string", "char", "unit", "obj",
    "byte", "sbyte", "int16", "uint16", "uint", "float32", "single", "printfn", "downto", "printf",
    "class", "Map"
]

// Операторы F#
let fsharpOperators: Set<String> = [
    "+", "-", "*", "/", "%", "=", "<", ">", "<=", ">=", "<>", "&&", "||", "!", "|>", ">>", "<<",
    "::", "@", "^", "~", "?", ":", "->", "<-", "|", "&", ";;", "(", ")", "[", "]", "{", "}", ",",
    ".", "..", ";", "**", "not", "&&&", "|||", "^^^", "~~~", "<<<", ">>>", "$",
]