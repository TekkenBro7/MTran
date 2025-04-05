import CDispatch

import Foundation

class Parser {
    private let tokens: [Token]
    private var current = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    private func isNumber(_ value: String) -> Bool {
        return Int(value) != nil
    }

    private func peek() -> Token {
        return tokens[current]
    }

    private func next(offset: Int = 1) -> Token {
        if current + offset < tokens.count {
            return tokens[current + offset]
        }
        fatalError("Неожиданный конец токенов")
    }

    private func consume() -> Token {
        guard current < tokens.count else {
            fatalError("Попытка чтения за пределами массива токенов")
        }
        let token = tokens[current]
        current += 1
        return token
    }

    private func match(_ type: TokenType, value: String? = nil) -> Bool {
        if current < tokens.count && tokens[current].type == type {
            if let value = value {
                return tokens[current].value == value
            }
            return true
        }
        return false
    }

    func parseProgram() -> ASTNode {
        let root = ASTNode(type: "Program")

        while current < tokens.count {
            if match(.error) {
                fatalError("Ошибка в строке \(peek().line)")
            } else if match(.keyword, value: "if") {
                root.addChild(parseIfStatement())
            } else if match(.keyword, value: "let") {
                // Проверяем, является ли это объявлением функции
                let nextToken = next()
                if nextToken.type == .identifier && tokens[current + 2].value == "(" {
                    Logger.log("Нашли функцию \(nextToken.value)")
                    root.addChild(parseFunctionDeclaration())
                } else {
                    root.addChild(parseVariableDeclaration())
                }
            } else if match(.keyword, value: "type") {
                root.addChild(parseClassDeclaration())
            } else if match(.keyword, value: "printfn") || match(.keyword, value: "print") {
                root.addChild(parsePrintfn())
            } else if match(.keyword, value: "while") {
                root.addChild(parseWhileStatement())
            } else if match(.keyword, value: "for") {
                // Проверяем, какой тип цикла for
                Logger.log("Токен ГЛАВНЫЙ \(peek().value)")
                let nextToken = next(offset: 2)
                if nextToken.value == "=" {
                    Logger.log("FOR TO \(peek().value)")
                    root.addChild(parseForToStatement())
                } else if nextToken.value == "in" {
                    Logger.log("FOR IN \(peek().value)")
                    root.addChild(parseForInStatement())
                } else {
                    fatalError("Неожиданный токен после 'for': \(nextToken.value)")
                }
            } else if match(.identifier) {

                let nextToken = next()
                // Проверяем, является ли это доступом к элементу массива (array.[index])
                if nextToken.value == "." && tokens.count > current + 2
                    && tokens[current + 2].value == "["
                {
                    Logger.log("ggg")
                    root.addChild(parseExpression())  // Обрабатываем как выражение
                } else if match(.identifier) && next(offset: 1).value == "(" {
                    root.addChild(parseFunctionCall())
                } else {
                    Logger.log("+++++ \(peek().value)")
                    root.addChild(parseAssignment())
                }
            } else {
                fatalError("Неизвестный токен")
            }
        }
        return root
    }

    private func parseFunctionCall() -> ASTNode {
        let functionName = consume()  // Имя функции
        let functionCallNode = ASTNode(
            type: "FunctionCall", value: functionName.value, line: functionName.line)
        consume()  // Пропускаем "("
        let argumentsNode = ASTNode(type: "Arguments", line: functionName.line)
        while !match(.operatorToken, value: ")") {
            let argument = consume()
            let argumentNode = ASTNode(type: "Argument", value: argument.value, line: argument.line)
            argumentsNode.addChild(argumentNode)

            if match(.operatorToken, value: ",") {
                consume()  // Пропускаем ","
            }
        }
        consume()  // Пропускаем ")"
        // Добавляем узел Arguments только если есть аргументы
        if argumentsNode.children.count > 0 {
            functionCallNode.addChild(argumentsNode)
        }
        return functionCallNode
    }

    private func parseFunctionDeclaration() -> ASTNode {
        let functionNodee = consume()  // Пропускаем "let"
        let functionNode = ASTNode(type: "FunctionDeclaration", line: functionNodee.line)

        // Парсим имя функции
        let functionName = consume()
        let functionNameNode = ASTNode(
            type: "FunctionName", value: functionName.value, line: functionName.line)
        functionNode.addChild(functionNameNode)

        // Парсим параметры функции
        if match(.operatorToken, value: "(") {
            consume()  // Пропускаем "("

            if !match(.operatorToken, value: ")") {
                let parametersNode = ASTNode(type: "Parameters")
                while !match(.operatorToken, value: ")") {
                    let parameter = consume()
                    let parameterNode = ASTNode(
                        type: "Parameter", value: parameter.value, line: parameter.line)
                    parametersNode.addChild(parameterNode)
                    if match(.operatorToken, value: ",") {
                        consume()  // Пропускаем ","
                    }
                }
                functionNode.addChild(parametersNode)
            }

            consume()  // Пропускаем ")"
        }

        // Пропускаем "="
        if match(.operatorToken, value: "=") {
            consume()
        }

        // Парсим тело функции
        let bodyNode = ASTNode(type: "Body")
        let initialIndentation = peek().indentationLevel

        while current < tokens.count && peek().indentationLevel >= initialIndentation {
            let statement = parseStatement()
            if statement.type != "UnknownStatement" {
                bodyNode.addChild(statement)
            }
        }
        Logger.log("последний символ \(bodyNode.children.last?.value)")
        // Обработка возвратов
        if let lastStatement = bodyNode.children.last {
            if lastStatement.type != "Printfn" && lastStatement.type != "Printf" {
                let returnNode = ASTNode(type: "Return")
                returnNode.addChild(lastStatement)  // Добавляем последний узел как возвращаемое значение
                bodyNode.children.removeLast()  // Удаляем последний узел
                bodyNode.addChild(returnNode)  // Добавляем узел return
            }
        }

        functionNode.addChild(bodyNode)

        return functionNode
    }

    private func parseWhileStatement() -> ASTNode {
        let whileNodee = consume()  // Пропускаем "while"
        let whileNode = ASTNode(type: "WhileStatement", line: whileNodee.line)
        // Парсим условие
        whileNode.addChild(parseCondition())

        Logger.log("ТЕКУЩИЙ \(peek().value)")
        Logger.log("Сдедующий \(next().value)")
        // Пропускаем "do"
        if match(.keyword, value: "do") {
            consume()  // Пропускаем "do"
        }
        Logger.log("ТЕКУЩИЙ \(peek().value)")
        Logger.log("ТЕКУЩИЙ \(next().value)")

        // Парсим тело цикла
        let bodyNode = ASTNode(type: "Body")
        let initialIndentation = peek().indentationLevel

        while current < tokens.count && peek().indentationLevel >= initialIndentation {
            bodyNode.addChild(parseStatement())
        }

        whileNode.addChild(bodyNode)

        return whileNode
    }

    private func parseVariableDeclaration() -> ASTNode {
        // Пропускаем 'let'
        _ = consume()

        let isMutable = match(.keyword, value: "mutable")
        if isMutable {
            _ = consume()
        }

        // Получаем имя переменной
        let varName = consume()
        let line = varName.line
        guard varName.type == .identifier else {
            fatalError(
                "Ожидался идентификатор переменной, но получено: '\(varName.value)' в строке \(varName.line)"
            )
        }

        let varNode = ASTNode(type: "VariableDeclaration", value: varName.value, line: line)

        if isMutable {
            varNode.addChild(ASTNode(type: "Modifier", value: "mutable"))
        }

        // Парсим тип переменной
        if match(.operatorToken, value: ":") {
            _ = consume()
            let typeToken = consume()
            varNode.addChild(ASTNode(type: "Type", value: typeToken.value))
        }

        // Парсим значение переменной
        if match(.operatorToken, value: "=") || match(.operatorToken, value: "<-") {
            _ = consume()

            // Проверяем специальные случаи для списков/массивов/map/set
            let nextToken = peek()
            if nextToken.value == "[" || nextToken.value == "[|" || nextToken.value == "Map"
                || nextToken.value == "Set"
            {
                // Разрешаем эти специальные конструкции
                varNode.addChild(parseExpression())
            } else if nextToken.type == .operatorToken
                && !["[", "[|", "Map", "Set"].contains(nextToken.value)
            {
                // Запрещаем другие операторы
                fatalError(
                    "Недопустимое значение переменной: '\(nextToken.value)' в строке \(nextToken.line)"
                )
            } else {
                varNode.addChild(parseExpression())
            }
        } else if !isAtEnd() {
            let nextToken = peek()
            if nextToken.indentationLevel == varName.indentationLevel {
                fatalError(
                    "Недопустимый синтаксис: ожидалось '=' или конец строки, но получено '\(nextToken.value)' в строке \(nextToken.line)"
                )
            }
        }

        return varNode
    }

    private func isAtEnd() -> Bool {
        return current >= tokens.count
    }

    private func parseAssignment() -> ASTNode {
        let varName = consume()  // Имя переменной
        let assignNode = ASTNode(type: "Assignment", value: varName.value, line: varName.line)

        if match(.operatorToken, value: "=") || match(.operatorToken, value: "<-") {
            consume()  // Пропускаем "="
            assignNode.addChild(parseExpression())
        }

        return assignNode
    }

    private func parseStatement() -> ASTNode {
        if match(.keyword, value: "if") {
            return parseIfStatement()
        } else if match(.keyword, value: "let") {
            // Проверяем, является ли это объявлением функции
            let nextToken = next()
            if nextToken.type == .identifier && tokens[current + 2].value == "(" {
                return parseFunctionDeclaration()
            } else {
                return parseVariableDeclaration()
            }
        } else if match(.keyword, value: "type") {
            return parseClassDeclaration()
        } else if match(.keyword, value: "while") {
            return parseWhileStatement()
        } else if match(.keyword, value: "for") {
            // Проверяем, какой тип цикла for
            Logger.log("ААА \(peek().value)")
            let nextToken = next(offset: 2)
            if nextToken.value == "=" {
                Logger.log("ААА FOR TO \(nextToken.value)")
                return parseForToStatement()
            } else if nextToken.value == "in" {
                Logger.log("ААА FOR IN \(nextToken.value)")
                return parseForInStatement()
            } else {
                fatalError("Неожиданный токен после 'for': \(nextToken.value)")
            }
        } else if match(.identifier) {
            Logger.log("Текущий--- \(peek().value)")
            Logger.log("Следующий--- \(next(offset: 1).value)")
            if match(.identifier) && next(offset: 1).value == "(" {
                return parseFunctionCall()
            } else {
                return parseAssignment()
            }
        } else if match(.keyword, value: "printfn") || match(.keyword, value: "printf") {
            Logger.log("йоу")
            return parsePrintfn()
        } else if match(.keyword, value: "return") {
            return parseReturn()
        } else {
            consume()  // Пропускаем неизвестные токены
            return ASTNode(type: "UnknownStatement")
        }
    }

    private func parseClassDeclaration() -> ASTNode {
        consume()  // Пропускаем "type"
        let className = consume()
        let classNode = ASTNode(type: "Class", value: className.value, line: className.line)

        // Парсим параметры конструктора, если они есть
        if match(.operatorToken, value: "(") {
            consume()  // Пропускаем "("
            Logger.log("Конструктор класса \(peek().value)")

            // Проверяем, есть ли параметры
            if !match(.operatorToken, value: ")") {
                let constructorParamsNode = ASTNode(type: "ConstructorParameters")

                while !match(.operatorToken, value: ")") {
                    // Парсим имя параметра
                    let paramName = consume()
                    let paramNode = ASTNode(
                        type: "Parameter", value: paramName.value, line: paramName.line)

                    // Если есть тип, парсим его
                    if match(.operatorToken, value: ":") {
                        consume()  // Пропускаем ":"
                        if current < tokens.count {
                            let paramType = consume()
                            let typeNode = ASTNode(
                                type: "Type", value: paramType.value, line: paramType.line)
                            paramNode.addChild(typeNode)
                        } else {
                            fatalError("Неожиданный конец токенов при парсинге типа параметра")
                        }
                    }
                    constructorParamsNode.addChild(paramNode)
                    // Пропускаем запятую, если она есть
                    if match(.operatorToken, value: ",") {
                        consume()  // Пропускаем ","
                    }
                }
                consume()  // Пропускаем ")"
                classNode.addChild(constructorParamsNode)  // Добавляем только если есть параметры
            } else {
                consume()  // Пропускаем ")" если нет параметров
            }
        }
        consume()  // Пропускаем "="

        let initialIndentation = peek().indentationLevel
        let membersNode = ASTNode(type: "Members")
        var hasMembers = false  // Флаг для проверки наличия членов

        // Парсим тело класса
        while current < tokens.count && peek().indentationLevel >= initialIndentation {
            if match(.keyword, value: "member") {
                hasMembers = true
                membersNode.addChild(parseMember())
            } else {
                consume()  // Пропускаем неизвестные токены
            }
        }

        if hasMembers {
            classNode.addChild(membersNode)  // Добавляем узел Members, если есть члены
        }

        return classNode
    }

    private func parseMember() -> ASTNode {
        consume()  // Пропускаем "member"
        consume()  // Пропускаем "this"
        consume()  // Пропускаем "."
        let memberName = consume()  // Имя члена (поля или метода)
        let memberNode = ASTNode(
            type: "MemberDefinition", value: memberName.value, line: memberName.line)

        // Если это метод (есть скобки)
        if match(.operatorToken, value: "(") {
            // Парсим параметры метода
            consume()  // Пропускаем "("
            let methodParamsNode = ASTNode(type: "MethodParameters")
            var hasParameters = false  // Флаг для проверки наличия параметров

            while !match(.operatorToken, value: ")") {
                // Парсим имя параметра
                let paramName = consume()
                let paramNode = ASTNode(
                    type: "Parameter", value: paramName.value, line: paramName.line)
                hasParameters = true  // Параметр присутствует

                // Если есть тип, парсим его
                if match(.operatorToken, value: ":") {
                    consume()  // Пропускаем ":"
                    if current < tokens.count {
                        let paramType = consume()
                        let typeNode = ASTNode(
                            type: "Type", value: paramType.value, line: paramType.line)
                        paramNode.addChild(typeNode)
                    } else {
                        fatalError("Неожиданный конец токенов при парсинге типа параметра")
                    }
                }

                methodParamsNode.addChild(paramNode)

                // Пропускаем запятую, если она есть
                if match(.operatorToken, value: ",") {
                    consume()  // Пропускаем ","
                }
            }

            consume()  // Пропускаем ")"
            if hasParameters {
                memberNode.addChild(methodParamsNode)  // Добавляем, только если есть параметры
            }

            // Пропускаем "="
            if match(.operatorToken, value: "=") {
                consume()  // Пропускаем "="
            }

            // Парсим тело метода
            let bodyNode = ASTNode(type: "Body")
            let initialIndentation = peek().indentationLevel

            while current < tokens.count && peek().indentationLevel >= initialIndentation {
                bodyNode.addChild(parseStatement())
            }

            memberNode.addChild(bodyNode)
        } else if match(.operatorToken, value: "=") {
            // Если это поле (есть "=")
            consume()  // Пропускаем "="

            // Парсим значение поля, если оно есть
            if match(.identifier) {
                let fieldValue = consume()
                let fieldNode = ASTNode(
                    type: "Field", value: fieldValue.value, line: fieldValue.line)
                memberNode.addChild(fieldNode)
            }
        }

        return memberNode
    }

    private func parsePrintfn() -> ASTNode {
        // Определяем, какой тип узла создавать: Printfn или Print
        let isPrintfN = match(.keyword, value: "printfn")
        let isPrintf = match(.keyword, value: "printf")

        var printNode: ASTNode

        // Проверяем, что это либо printfn, либо printf
        if isPrintfN {
            let a = consume()  // Пропускаем "printfn"
            printNode = ASTNode(type: "Printfn", line: a.line)
        } else if isPrintf {
            let b = consume()  // Пропускаем "printf"
            printNode = ASTNode(type: "Printf", line: b.line)
        } else {
            fatalError("Неожиданный токен для printf или printfn")
        }

        Logger.log("ТЕКУЩИЙ1 \(peek().value)")
        if current + 1 < tokens.count {
            Logger.log("ТЕКУЩИЙ2 \(next().value)")
        }
        //    Logger.log("ТЕКУЩИЙ3 \(next(offset: 2).value)")
        //    Logger.log("ТЕКУЩИЙ4 \(next(offset: 3).value)")
        let initialLine = peek().line
        // Проверяем, есть ли символ $ перед строкой
        if match(.operatorToken, value: "$") {
            consume()  // Пропускаем "$"
            if match(.stringLiteral) {
                let c = consume()
                let stringNode = ASTNode(type: "InterpolatedString", value: c.value, line: c.line)
                printNode.addChild(stringNode)
            }
        } else if match(.stringLiteral) {
            // Обычная строка без интерполяции
            Logger.log("Строка \(peek().value)")
            let d = consume()
            let stringNode = ASTNode(type: "StringLiteral", value: d.value, line: d.line)
            printNode.addChild(stringNode)
        }

        // Обработка аргументов, если они есть и на одной строке
        while current < tokens.count && peek().line == initialLine {
            Logger.log("\(peek().value) \(peek().line)")
            let argumentNode = parseExpression()  // Парсим следующее выражение
            printNode.addChild(argumentNode)  // Добавляем его как дочерний узел
        }

        Logger.log(
            "Обработанный Printfn: \(printNode.type) с \(printNode.children.count) аргументами")

        return printNode
    }

    private func parseReturn() -> ASTNode {
        let e = consume()  // Пропускаем "return"
        let returnNode = ASTNode(type: "Return", line: e.line)

        if match(.number) || match(.identifier) {
            returnNode.addChild(parseExpression())
        }

        return returnNode
    }

    private func parseExpression() -> ASTNode {
        return parseAddition()
    }

    private func parseAddition() -> ASTNode {
        var left = parseMultiplication()

        while match(.operatorToken, value: "+") || match(.operatorToken, value: "-") {
            let op = consume()
            let right = parseMultiplication()
            let exprNode = ASTNode(type: "BinaryOp", value: op.value, line: op.line)
            exprNode.addChild(left)
            exprNode.addChild(right)
            left = exprNode
        }

        return left
    }

    private func parseMultiplication() -> ASTNode {
        var left = parseTerm()

        while match(.operatorToken, value: "*") || match(.operatorToken, value: "/") {
            let op = consume()
            let right = parseTerm()
            let exprNode = ASTNode(type: "BinaryOp", value: op.value, line: op.line)
            exprNode.addChild(left)
            exprNode.addChild(right)
            left = exprNode
        }

        return left
    }

    private func parseTerm() -> ASTNode {
        Logger.log("Текущий СИМВОЛ \(peek().value)")
        if match(.error) {
            fatalError("Ошибка в строке \(peek().line)")
        } else if match(.operatorToken, value: "(") {
            consume()  // Пропускаем "("
            let expr = parseExpression()
            if match(.operatorToken, value: ")") {
                consume()  // Пропускаем ")"
            }
            Logger.log("Парсинг выражения в скобках")
            return expr
        } else if match(.number) {
            let a = consume()
            let numberNode = ASTNode(type: "Number", value: a.value, line: a.line)
            Logger.log("Парсинг числа: \(numberNode.value)")
            return numberNode
        } else if match(.floatNumber) {
            let a = consume()
            let floatNode = ASTNode(type: "Float_number", value: a.value, line: a.line)
            Logger.log("Парсинг числа с плавающей точкой: \(floatNode.value)")
            return floatNode
        } else if match(.stringLiteral) {
            let a = consume()
            let stringNode = ASTNode(type: "String_literal", value: a.value, line: a.line)
            Logger.log("Парсинг строкового литерала: \(stringNode.value)")
            return stringNode
        } else if match(.charLiteral) {
            let a = consume()
            let charNode = ASTNode(type: "Char_literal", value: a.value, line: a.line)
            Logger.log("Парсинг символа: \(charNode.value)")
            return charNode
        } else if match(.identifier) {
            if match(.identifier) && next().value == "(" {
                return parseFunctionCall()
            } else {
                let identifier = consume()
                Logger.log("Парсинг идентификатора: \(identifier.value)")

                // Специальная обработка для Set.ofArray
                if identifier.value == "Set" && match(.operatorToken, value: ".") {
                    consume()  // Пропускаем "."
                    let property = consume()
                    if property.value == "ofArray" {
                        return parseSetOfArray()
                    }
                }

                // Обработка доступа к массиву array.[index]
                if match(.operatorToken, value: ".") {
                    consume()  // Пропускаем "."

                    // Проверяем, является ли это доступом к массиву
                    if match(.operatorToken, value: "[") {
                        consume()  // Пропускаем "["

                        // Специальная обработка отрицательных индексов
                        if match(.operatorToken, value: "-") {
                            let minusToken = consume()
                            if match(.number) {
                                let numberToken = consume()
                                let negativeNumberNode = ASTNode(
                                    type: "Number",
                                    value: "-" + numberToken.value,
                                    line: minusToken.line
                                )

                                let arrayAccessNode = ASTNode(
                                    type: "ArrayAccess",
                                    value: identifier.value,
                                    line: identifier.line
                                )
                                arrayAccessNode.addChild(negativeNumberNode)

                                if match(.operatorToken, value: "]") {
                                    consume()  // Пропускаем "]"
                                }
                                return arrayAccessNode
                            }
                        }

                        let arrayAccessNode = ASTNode(
                            type: "ArrayAccess", value: identifier.value, line: identifier.line)
                        arrayAccessNode.addChild(parseExpression())  // Парсим индекс
                        if match(.operatorToken, value: "]") {
                            consume()  // Пропускаем "]"
                        }
                        return arrayAccessNode
                    }

                    // Обработка обычного доступа к свойству
                    let property = consume()
                    return ASTNode(
                        type: "PropertyAccess", value: property.value, line: property.line)
                }

                if identifier.value == "seq" {
                    return parseSequence()
                }
                if match(.operatorToken, value: ".") {
                    consume()  // Пропускаем "."
                    let property = consume()
                    Logger.log(
                        "Парсинг доступа к свойству: \(property.value) идентификатора \(identifier.value)"
                    )
                    if property.value == "ofArray" && identifier.value == "Set" {
                        return parseSetOfArray()
                    }
                    let propertyNode = ASTNode(type: "PropertyAccess", value: property.value)
                    propertyNode.addChild(ASTNode(type: "Identifier", value: identifier.value))
                    return propertyNode
                }
                return ASTNode(type: "Identifier", value: identifier.value, line: identifier.line)
            }
        } else if match(.keyword, value: "true") || match(.keyword, value: "false") {
            let boolNode = ASTNode(type: "Boolean_literal", value: consume().value)
            Logger.log("Парсинг булевого литерала: \(boolNode.value)")
            return boolNode
        } else if match(.operatorToken, value: "[|") || match(.operatorToken, value: "[") {
            Logger.log("Парсинг массива или списка")
            return parseArrayOrList()
        } else if match(.keyword, value: "Map") {
            Logger.log("Парсинг Map")
            return parseMap()
        } else {
            fatalError("Неожиданный токен: \(peek().value)")
        }
    }

    private func parseIfStatement() -> ASTNode {
        Logger.log("Текущий символ \(peek().value)")
        let a = consume()  // Пропускаем "if"
        let ifNode = ASTNode(type: "IfStatement", line: a.line)

        // Парсим условие, проверяем на наличие скобок
        Logger.log("Текущий символ \(peek().value)")
        if match(.operatorToken, value: "(") {
            consume()  // Пропускаем "("
            ifNode.addChild(parseCondition())
            if match(.operatorToken, value: ")") {
                consume()  // Пропускаем ")"
            }
        } else {
            // Если скобок нет, парсим условие напрямую
            ifNode.addChild(parseCondition())
        }

        // Парсим блок "then"
        if match(.keyword, value: "then") {
            let b = consume()  // Пропускаем "then"
            let thenBlock = ASTNode(type: "ThenBlock", line: b.line)
            let initialIndentation = peek().indentationLevel

            while current < tokens.count && peek().indentationLevel >= initialIndentation {
                thenBlock.addChild(parseStatement())
            }
            ifNode.addChild(thenBlock)
        }

        // Парсим ветки "elif"
        while match(.keyword, value: "elif") {
            let c = consume()  // Пропускаем "elif"
            let elifNode = ASTNode(type: "ElifStatement", line: c.line)

            // Парсим условие, проверяем на наличие скобок
            if match(.operatorToken, value: "(") {
                consume()  // Пропускаем "("
                elifNode.addChild(parseCondition())
                if match(.operatorToken, value: ")") {
                    consume()  // Пропускаем ")"
                }
            } else {
                // Если скобок нет, парсим условие напрямую
                elifNode.addChild(parseCondition())
            }

            // Парсим блок "then" для "elif"
            if match(.keyword, value: "then") {
                let d = consume()  // Пропускаем "then"
                let elifThenBlock = ASTNode(type: "ThenBlock", line: d.line)
                let initialIndentation = peek().indentationLevel

                while current < tokens.count && peek().indentationLevel >= initialIndentation {
                    elifThenBlock.addChild(parseStatement())
                }
                elifNode.addChild(elifThenBlock)
            }
            ifNode.addChild(elifNode)

        }

        // Парсим ветку "else"
        if match(.keyword, value: "else") {
            let e = consume()  // Пропускаем "else"
            let elseBlock = ASTNode(type: "ElseBlock", line: e.line)
            let initialIndentation = peek().indentationLevel

            while current < tokens.count && peek().indentationLevel >= initialIndentation {
                elseBlock.addChild(parseStatement())
            }
            ifNode.addChild(elseBlock)
        }

        return ifNode
    }

    private func parseForToStatement() -> ASTNode {
        let a = consume()  // Пропускаем "for"
        let forNode = ASTNode(type: "ForToStatement", line: a.line)
        // Парсим идентификатор
        let identifier = consume()
        let identifierNode = ASTNode(
            type: "Identifier", value: identifier.value, line: identifier.line)
        forNode.addChild(identifierNode)
        // Пропускаем "="
        if match(.operatorToken, value: "=") {
            consume()
        }
        // Парсим начальное значение
        let startValue = parseExpression()
        let startValueNode = ASTNode(type: "StartValue")
        startValueNode.addChild(
            ASTNode(type: "Type", value: startValue.type, line: startValue.line))
        startValueNode.addChild(
            ASTNode(type: "Value", value: startValue.value, line: startValue.line))
        forNode.addChild(startValueNode)
        // Парсим направление (to или downto)
        if match(.keyword, value: "to") || match(.keyword, value: "downto") {
            let direction = consume()
            let directionNode = ASTNode(
                type: "Direction", value: direction.value, line: direction.line)
            forNode.addChild(directionNode)
        }

        // Парсим конечное значение
        let endValue = parseExpression()
        let endValueNode = ASTNode(type: "EndValue")
        endValueNode.addChild(ASTNode(type: "Type", value: endValue.type, line: endValue.line))
        endValueNode.addChild(ASTNode(type: "Value", value: endValue.value, line: endValue.line))
        forNode.addChild(endValueNode)

        // Пропускаем "do"
        if match(.keyword, value: "do") {
            consume()
        }

        // Парсим тело цикла
        let bodyNode = ASTNode(type: "Body")
        let initialIndentation = peek().indentationLevel

        while current < tokens.count && peek().indentationLevel >= initialIndentation {
            bodyNode.addChild(parseStatement())
        }

        forNode.addChild(bodyNode)

        return forNode
    }

    private func parseForInStatement() -> ASTNode {
        consume()  // Пропускаем "for"
        let forNode = ASTNode(type: "ForInStatement")

        // Парсим идентификатор
        let identifier = consume()
        let identifierNode = ASTNode(
            type: "Identifier", value: identifier.value, line: identifier.line)
        forNode.addChild(identifierNode)

        // Пропускаем "in"
        if match(.keyword, value: "in") {
            consume()
        }

        let collection: ASTNode
        if match(.number) {
            let left = parseTerm()
            if match(.operatorToken, value: "..") {
                consume()  // Пропускаем ".."
                let right = parseTerm()
                collection = ASTNode(
                    type: "Range", value: "\(left.value)..\(right.value)", line: right.line)
            } else {
                collection = parseExpression()
            }
        } else {
            collection = parseExpression()
        }

        forNode.addChild(collection)

        // Пропускаем "do"
        if match(.keyword, value: "do") {
            consume()
        }

        // Парсим тело цикла
        let bodyNode = ASTNode(type: "Body")
        let initialIndentation = peek().indentationLevel

        while current < tokens.count && peek().indentationLevel >= initialIndentation {
            bodyNode.addChild(parseStatement())
        }

        forNode.addChild(bodyNode)

        return forNode
    }

    private func parseCondition() -> ASTNode {
        let conditionNode = ASTNode(type: "Condition", line: peek().line)

        // Парсим левую часть условия
        let left = parseExpression()
        conditionNode.addChild(left)

        // Парсим оператор сравнения
        if match(.operatorToken, value: "==") || match(.operatorToken, value: "!=")
            || match(.operatorToken, value: "<") || match(.operatorToken, value: ">")
            || match(.operatorToken, value: "<=") || match(.operatorToken, value: ">=")
        {
            let op = consume()
            let opNode = ASTNode(type: "Operator", value: op.value, line: op.line)
            conditionNode.addChild(opNode)

            // Парсим правую часть условия
            let right = parseExpression()
            conditionNode.addChild(right)
        }
        if match(.operatorToken, value: ")") {
            consume()
        }
        return conditionNode
    }

    private func parseSetOfArray() -> ASTNode {
        Logger.log("Парсинг Set")
        Logger.log("Текущий символввв \(peek().value)")
        let setNode = ASTNode(type: "SetDeclaration")
        if match(.operatorToken, value: "[") && next().value == "|" {
            consume()
            consume()
            while !match(.operatorToken, value: "|") {
                setNode.addChild(parseExpression())
                if match(.operatorToken, value: ";") {
                    consume()  // Пропускаем ";"
                }
            }
            consume()  // Пропускаем "|]"
            consume()
        }
        return setNode
    }

    private func parseArrayOrList() -> ASTNode {
        if match(.operatorToken, value: "[") {
            consume()  // Пропускаем "["
            // Проверяем следующий токен
            if match(.operatorToken, value: "|") {
                consume()  // Пропускаем "|"
                Logger.log("Парсинг массива")
                return parseArray()  // Обработка массива
            } else {
                Logger.log("Парсинг списка")
                return parseList()  // Обработка списка
            }
        } else {
            fatalError("Неожиданный токен: \(peek().value)")
        }
    }

    private func parseArray() -> ASTNode {
        let arrayNode = ASTNode(type: "ArrayDeclaration")
        while !match(.operatorToken, value: "|") {
            arrayNode.addChild(parseExpression())
            if match(.operatorToken, value: ";") {
                consume()  // Пропускаем ";"
            }
        }
        consume()
        consume()  // Пропускаем "|]"
        return arrayNode
    }

    private func parseList() -> ASTNode {
        let listNode = ASTNode(type: "ListDeclaration")
        while !match(.operatorToken, value: "]") {
            listNode.addChild(parseExpression())
            if match(.operatorToken, value: ";") {
                consume()  // Пропускаем ";"
            }
        }
        consume()  // Пропускаем "]"
        return listNode
    }

    private func parseSequence() -> ASTNode {
        Logger.log("Парсинг последовательности")
        Logger.log("Текущий символ \(peek().value)")
        let seqNode = ASTNode(type: "SequenceDeclaration")
        if match(.operatorToken, value: "{") {
            consume()  // Пропускаем "{"
            Logger.log("Текущий символ2 \(peek().value)")
            while !match(.operatorToken, value: "}") {
                // Проверяем на наличие диапазона
                Logger.log("Текущий символ3 \(next(offset: 1).value)")
                Logger.log("Текущий символ3 \(next(offset: 2).value)")
                if next(offset: 1).value == ".." && isNumber(next(offset: 2).value) {
                    Logger.log(".. присутствует")
                    let start = consume()  // Начало диапазона
                    consume()  // Пропускаем ".."
                    let end = consume()  // Конец диапазона
                    let rangeNode = ASTNode(
                        type: "Range", value: "\(start.value)..\(end.value)", line: end.line)
                    seqNode.addChild(rangeNode)
                } else {
                    // Обрабатываем обычное выражение
                    seqNode.addChild(parseExpression())
                }
                if match(.operatorToken, value: ";") {
                    consume()  // Пропускаем ";"
                }
            }
            consume()  // Пропускаем "}"
        }
        return seqNode
    }

    private func parseMap() -> ASTNode {
        let mapNode = ASTNode(type: "MapDeclaration")
        if match(.keyword, value: "Map") {
            consume()  // Пропускаем "Map"
            if match(.operatorToken, value: "[") {
                consume()  // Пропускаем "["
                while !match(.operatorToken, value: "]") {
                    let key = parseExpression()
                    if match(.operatorToken, value: ",") {
                        consume()  // Пропускаем ","
                    }
                    let value = parseExpression()
                    let pairNode = ASTNode(type: "KeyValuePair", line: value.line)
                    pairNode.addChild(key)
                    pairNode.addChild(value)
                    mapNode.addChild(pairNode)
                    if match(.operatorToken, value: ";") {
                        consume()  // Пропускаем ";"
                    }
                }
                consume()  // Пропускаем "]"
            }
        }
        return mapNode
    }
}
extension Parser {

    private func verifyBalancedParentheses() throws {
        var stack = [Token]()
        for token in tokens {
            if token.value == "(" {
                stack.append(token)
            } else if token.value == ")" {
                if stack.isEmpty {
                    throw ParseError.unmatchedClosingParenthesis(line: token.line)
                }
                stack.removeLast()
            }
        }
        if !stack.isEmpty {
            throw ParseError.unmatchedOpeningParenthesis(line: stack.last!.line)
        }
    }

    private func checkConsecutiveOperators() throws {
        var prevToken: Token? = nil
        for token in tokens {
            if let prev = prevToken, isOperator(prev.value), isOperator(token.value) {
                // Пропускаем комбинации, которые могут быть допустимы (например, "->")
                throw ParseError.consecutiveOperators(
                    first: prev.value, second: token.value, line: token.line)
            }
            prevToken = token
        }
    }

    private func isOperator(_ value: String) -> Bool {
        let operators = ["+", "-", "*", "/", "=", "<", ">", "==", "!=", "<=", ">="]
        return operators.contains(value)
    }

    public func validateTokens() throws {
        Logger.log(".. присутствует")
        try verifyBalancedParentheses()
        Logger.log(".. присутствует")

        try checkConsecutiveOperators()
    }
}
enum ParseError: Error, CustomStringConvertible {
    case unmatchedOpeningParenthesis(line: Int)
    case unmatchedClosingParenthesis(line: Int)
    case consecutiveOperators(first: String, second: String, line: Int)
    case invalidSyntax(message: String, line: Int)
    case unexpectedToken(expected: String, actual: String, line: Int)
    case invalidVariableDeclaration(message: String, line: Int)

    var description: String {
        switch self {
        case .invalidVariableDeclaration(let message, let line):
            return "Ошибка в строке \(line): Некорректное объявление переменной - \(message)"
        case .unmatchedOpeningParenthesis(let line):
            return "Ошибка в строке \(line): Незакрытая скобка"
        case .unmatchedClosingParenthesis(let line):
            return "Ошибка в строке \(line): Закрывающая скобка без открывающей"
        case .consecutiveOperators(let first, let second, let line):
            return "Ошибка в строке \(line): Несколько операторов подряд '\(first)' и '\(second)'"
        case .invalidSyntax(let message, let line):
            return "Ошибка в строке \(line): \(message)"
        case .unexpectedToken(let expected, let actual, let line):
            return "Ошибка в строке \(line): Ожидалось '\(expected)', но получено '\(actual)'"
        }
    }
}
