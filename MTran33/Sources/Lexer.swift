import CDispatch
import Foundation

class Lexer {
    private let source: String
    private var pos: String.Index
    private var line: Int
    private var nextTokenId: Int
    private var tokens: [Token]
    private var tokenIds: [String: Int]
    private var indentationLevel: Int

    init(source: String) {
        self.source = source
        self.pos = source.startIndex
        self.line = 1
        self.nextTokenId = 1
        self.tokens = []
        self.tokenIds = [:]
        self.indentationLevel = 0
    }

    // Основная функция для токенизации
    func tokenize() -> [Token] {
        tokens = []
        while pos < source.endIndex {
            let currentChar = source[pos]
            Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
            if currentChar.isWhitespace {
                if currentChar == "\r\n" || currentChar == "\n" {
                    line += 1
                    indentationLevel = 0
                } else {
                    indentationLevel += 1
                }
                pos = source.index(after: pos)
            } else if currentChar == "["
                && (source.index(after: pos) < source.endIndex
                    && (source[source.index(after: pos)] == "<"))
            {
                tokens.append(consumeAttribute())
            } else if currentChar.isLetter || currentChar == "_" {
                tokens.append(consumeIdentifierOrKeyword())
            } else if currentChar.isNumber
                || (currentChar == "." && source.index(after: pos) < source.endIndex
                    && source[source.index(after: pos)].isNumber)
            {
                tokens.append(consumeNumber())
            } else if currentChar == "\"" {
                tokens.append(consumeStringLiteral())
            } else if currentChar == "'" {
                tokens.append(consumeCharLiteral())
            } else if (currentChar == "/"
                && (source.index(after: pos) < source.endIndex
                    && (source[source.index(after: pos)] == "/"
                        || source[source.index(after: pos)] == "*")))
                || (currentChar == "("
                    && (source.index(after: pos) < source.endIndex
                        && source[source.index(after: pos)] == "*"))
            {
                consumeComment()
                if source[pos] == ")" {
                    pos = source.index(after: pos)
                }
            } else if isOperator(String(currentChar)) {
                tokens.append(consumeOperator())
            } else {
                tokens.append(createToken(type: .error, value: String(currentChar)))
                pos = source.index(after: pos)
            }
        }
        return tokens
    }

    private func consumeAttribute() -> Token {
        let start = pos
        pos = source.index(after: pos)  // Пропускаем '['
        while pos < source.endIndex && source[pos] != "]" {
            pos = source.index(after: pos)
        }
        if pos < source.endIndex && source[pos] == "]" {
            pos = source.index(after: pos)  // Пропускаем ']'
            return createToken(type: .attribute, value: String(source[start..<pos]))
        }
        return createToken(type: .error, value: String(source[start..<pos]))
    }

    private func isOperator(_ op: String) -> Bool {
        return fsharpOperators.contains(op)
    }

    private func createToken(type: TokenType, value: String) -> Token {
        if tokenIds[value] == nil {
            tokenIds[value] = nextTokenId
            nextTokenId += 1
        }
        let token = Token(type: type, value: value, line: line, id: tokenIds[value]!, indentationLevel: indentationLevel)
        Logger.log(
            "Создан токен: \(token.type.rawValue) Значение: \(token.value) Строка: \(token.line) Id: \(token.id) Отступ: \(token.indentationLevel)"
        )
        return token
    }

    private func consumeIdentifierOrKeyword() -> Token {
        let start = pos
        while pos < source.endIndex
            && (source[pos].isLetter || source[pos].isNumber || source[pos] == "_")
        {
            pos = source.index(after: pos)
        }
        let word = String(source[start..<pos])
        return createToken(
            type: fsharpKeywords.contains(word) ? .keyword : .identifier, value: word)
    }

    private func consumeNumber() -> Token {
        let start = pos
        var isFloat = false

        Logger.log("Текущая позиция: \(source.startIndex)")

        // Обрабатываем знак перед числом, если он присутствует
        if pos > source.startIndex
            && (source[source.index(before: pos)] == "-"
                || source[source.index(before: pos)] == "+")
            && (source.index(before: pos) == source.startIndex
                || source[source.index(before: source.index(before: pos))].isWhitespace
                || source[source.index(before: source.index(before: pos))] == "=")
        {
            tokens.removeLast()
            pos = source.index(before: pos)
        }

        while pos < source.endIndex && (source[pos].isNumber || source[pos] == ".") {

            Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")

            if source[pos] == "." {

                // Проверяем, не является ли . началом ..
                if pos < source.index(before: source.endIndex)
                    && source[source.index(after: pos)] == "."
                {
                    break
                }

                if isFloat {
                    return createToken(type: .error, value: String(source[start..<pos]))
                }
                isFloat = true
            }
            pos = source.index(after: pos)
        }

        // Проверяем, начинается ли после числа оператор `..`
        if pos < source.index(before: source.endIndex) && source[pos] == "."
            && source[source.index(after: pos)] == "."
        {
            let numberToken = createToken(
                type: isFloat ? .floatNumber : .number, value: String(source[start..<pos]))
            pos = source.index(pos, offsetBy: 2)  // Пропускаем ..
            let rangeToken = createToken(type: .operatorToken, value: "..")

            tokens.append(numberToken)

            return rangeToken
        }

        // Обрабатываем экспоненциальную часть (e или E)
        if pos < source.endIndex && (source[pos] == "e" || source[pos] == "E") {
            Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
            isFloat = true
            pos = source.index(after: pos)
            // Обрабатываем возможные знаки (+ или -) после e/E
            if pos < source.endIndex && (source[pos] == "+" || source[pos] == "-") {
                pos = source.index(after: pos)
            }
            // После e/E должно быть хотя бы одно число
            if pos >= source.endIndex || !source[pos].isNumber {
                return createToken(type: .error, value: String(source[start..<pos]))
            }
            // Читаем оставшиеся цифры экспоненты
            while pos < source.endIndex && source[pos].isNumber {
                pos = source.index(after: pos)
            }
        }
        // Обрабатываем суффиксы типов (f, F, d, D)
        if pos < source.endIndex
            && (source[pos] == "f" || source[pos] == "F" || source[pos] == "d"
                || source[pos] == "D")
        {
            isFloat = true
            pos = source.index(after: pos)
        }

        // Обрабатываем целочисленные суффиксы (l, L, u, U, y, Y, n, N, uy, UY)
        if pos < source.endIndex {
            let currentChar = source[pos]
        }
        if pos < source.endIndex && ["l", "u", "y", "n"].contains(source[pos].lowercased()) {
            let currentChar = source[pos]
            let nextChar =
                pos < source.index(before: source.endIndex) ? source[source.index(after: pos)] : nil
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
            Logger.log("Следующий символ: \(nextChar)")
            // Проверяем одиночные суффиксы (l, L, u, U, y, Y, n, N)
            if currentChar.lowercased() == "l" || currentChar.lowercased() == "u"
                || currentChar.lowercased() == "y" || currentChar.lowercased() == "n"
            {
                pos = source.index(after: pos)
            }
            // Проверяем двойные суффиксы (uy, UY)
            if currentChar.lowercased() == "u" && nextChar?.lowercased() == "y" {
                pos = source.index(after: pos)
            }
        }
        if pos < source.endIndex {
            Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
        }
        // Проверяем на ошибку: если после числа идёт недопустимый символ (например, буква)
        if pos < source.endIndex && !source[pos].isWhitespace && !isOperator(String(source[pos])) {
            // Если после числа идет недопустимый символ, возвращаем ошибку для всего числа
            while pos < source.endIndex && !source[pos].isWhitespace
                && !isOperator(String(source[pos]))
            {
                pos = source.index(after: pos)
            }
            Logger.log("Cлово: \(String(source[start..<pos]))")
            return createToken(type: .error, value: String(source[start..<pos]))
        }
        return createToken(
            type: isFloat ? .floatNumber : .number, value: String(source[start..<pos]))
    }

    private func consumeStringLiteral() -> Token {
        let start = pos
        pos = source.index(after: pos)
        while pos < source.endIndex && source[pos] != "\"" {
            if source[pos] == "\\" && source.index(after: pos) < source.endIndex {
                pos = source.index(after: pos)
            }
            pos = source.index(after: pos)
        }
        if pos < source.endIndex && source[pos] == "\"" {
            pos = source.index(after: pos)
            return createToken(type: .stringLiteral, value: String(source[start..<pos]))
        }
        return createToken(type: .error, value: String(source[start..<pos]))
    }

    private func consumeCharLiteral() -> Token {
        let start = pos
        pos = source.index(after: pos)
        if pos < source.endIndex && source[pos] == "\\" {
            pos = source.index(after: pos)
        }
        pos = source.index(after: pos)
        if pos < source.endIndex && source[pos] == "'" {
            pos = source.index(after: pos)
            return createToken(type: .charLiteral, value: String(source[start..<pos]))
        }
        return createToken(type: .error, value: String(source[start..<pos]))
    }

    private func consumeComment() {
        if source[source.index(after: pos)] == "/" {
            pos = source.index(after: pos)
            while pos < source.endIndex && source[pos].unicodeScalars.first!.value != 13 {
                Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
                Logger.log(
                    "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
                pos = source.index(after: pos)
            }
            line += 1
            Logger.log("Завершение однострочного комментария из-за символа с кодом 13")
            if pos < source.endIndex {
                pos = source.index(after: pos)
            }
            return
        } else if source[source.index(after: pos)] == "*" {
            Logger.log("Начался многострочный")
            Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
            Logger.log(
                "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
            pos = source.index(after: pos)
            while source.index(after: pos) < source.endIndex
                && !(source[pos] == "*" && source[source.index(after: pos)] == ")")
            {
                pos = source.index(after: pos)
                if source[pos] == "\r\n" {
                    line += 1
                }
            }
            pos = source.index(after: pos)
            if source.index(after: pos) < source.endIndex {
                pos = source.index(after: pos)
                Logger.log("Текущая позиция: \(source.distance(from: source.startIndex, to: pos))")
                Logger.log(
                    "Текущий символ: \(source[pos]) (\(source[pos].unicodeScalars.first!.value))")
            }
            Logger.log("Завершение многострочного комментария комментария")
        }
    }

    private func consumeOperator() -> Token {
        let start = pos
        while pos < source.endIndex && isOperator(String(source[start..<source.index(after: pos)]))
        {
            pos = source.index(after: pos)
        }
        return createToken(type: .operatorToken, value: String(source[start..<pos]))
    }
}

