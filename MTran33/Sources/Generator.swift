import Foundation

class CodeGenerator {
    private var output = ""
    private var indentLevel = 0
    private var currentIndent: String {
        return String(repeating: " ", count: indentLevel * 4)
    }

    private let typeMap: [String: String] = [
        "int": "Int",
        "float": "Float",
        "double": "Double",
        "char": "Character",
        "bool": "Bool",
        "string": "String",
        "unit": "Void",
        "list": "Array",
        "array": "Array",
        "seq": "Array",
        "Map": "Dictionary",
        "Set": "Set",
    ]

    func generate(from node: ASTNode) -> String {
        output = ""
        generateNode(node)
        //return output
        return cleanGeneratedCode(output)
    }

    private func cleanGeneratedCode(_ code: String) -> String {
        let lines = code.components(separatedBy: .newlines)
        var cleanedLines = [String]()
        var lastLineWasEmpty = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                if !lastLineWasEmpty && !cleanedLines.isEmpty {
                    cleanedLines.append("")
                    lastLineWasEmpty = true
                }
            } else {
                cleanedLines.append(line)
                lastLineWasEmpty = false
            }
        }

        // Удаляем лишние пустые строки в конце
        while cleanedLines.last?.isEmpty == true {
            cleanedLines.removeLast()
        }

        return cleanedLines.joined(separator: "\n")
    }

    private func generateNode(_ node: ASTNode) {
        switch node.type {
        case "Program":
            generateProgram(node)
        case "FunctionDeclaration":
            generateFunction(node)
        case "VariableDeclaration":
            generateVariableDeclaration(node)
        case "IfStatement":
            generateIfStatement(node)
        case "WhileStatement":
            generateWhileStatement(node)
        case "ForInStatement":
            generateForInStatement(node)
        case "ForToStatement":
            generateForToStatement(node)
        case "FunctionCall":
            generateFunctionCall(node)
        case "BinaryOp":
            generateBinaryOp(node)
        case "Argument":
            generateNode(node.children.first ?? node)
        case "Assignment":
            generateAssignment(node)
        case "Return":
            generateReturn(node)
        case "Printfn":
            generatePrint(node, newline: true)
        case "Printf":
            generatePrint(node, newline: false)
        case "Class":
            generateClass(node)
        case "ThenBlock", "ElseBlock":
            // Обрабатываем все дочерние узлы блока
            indentLevel += 1
            for child in node.children {
                generateNode(child)
            }
            indentLevel -= 1
        case "Condition":
            generateCondition(node)
        case "MemberDefinition":
            generateMember(node)
        case "Number", "Float_number":
            let value = node.value.replacingOccurrences(of: "L", with: "")
            output += value
        //  output += node.value
        case "String_literal":
            var cleanedValue = node.value
            if cleanedValue.hasPrefix("\"") && cleanedValue.hasSuffix("\"") {
                cleanedValue = String(cleanedValue.dropFirst().dropLast())
            }
            output += "\"\(cleanedValue)\""
        case "Boolean_literal":
            output += node.value.lowercased()
        case "Identifier":
            output += node.value
        case "ArrayAccess":
            generateArrayAccess(node)
        case "PropertyAccess":
            generatePropertyAccess(node)
        case "ArrayOrList":
            generateArrayOrList(node)
        case "StartValue", "EndValue", "Range":
            // Обрабатываем дочерние узлы (Type и Value)
            for child in node.children {
                generateNode(child)
            }
        case "Type":
            // Тип обычно обрабатывается в родительском узле
            break
        case "Value":
            output += node.value
        case "Body":
            // Обрабатываем все дочерние узлы тела
            indentLevel += 1
            for child in node.children {
                generateNode(child)
                if !child.type.hasPrefix("If") && !child.type.hasPrefix("For")
                    && !child.type.hasPrefix("While") && child.type != "Body"
                {
                    output += "\n"
                }
            }
            indentLevel -= 1
        case "SetDeclaration":
            generateSetDeclaration(node)
        case "SequenceDeclaration":
            generateSequenceDeclaration(node)
        case "ListDeclaration":
            generateListDeclaration(node)
        case "MapDeclaration":
            generateMapDeclaration(node)
        case "ArrayDeclaration":
            generateArrayDeclaration(node)
        case "KeyValuePair":
            generateKeyValuePair(node)
        default:
            print("Warning: Unknown node type \(node.type)")
            for child in node.children {
                generateNode(child)
            }
        }
    }

    // MARK: - Program Structure

    private func generateProgram(_ node: ASTNode) {
        // Импорты по умолчанию
        output = "import Foundation\n\n"

        for (index, child) in node.children.enumerated() {
            generateNode(child)
            if index < node.children.count - 1 {
                output += "\n"
            }
        }
    }

    // MARK: - Declarations

    private func generateFunction(_ node: ASTNode) {
        guard let nameNode = node.children.first(where: { $0.type == "FunctionName" }) else {
            return
        }
        let name = nameNode.value

        // Параметры функции (явно указываем Int)
        var parameters = ""
        if let paramsNode = node.children.first(where: { $0.type == "Parameters" }) {
            parameters = paramsNode.children.map { "\($0.value ?? "_"): Int" }.joined(
                separator: ", ")
        }

        // Тело функции
        var body = ""
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            let oldOutput = output
            output = ""

            indentLevel += 1
            for child in bodyNode.children {
                generateNode(child)
                if child.type != "Return" && !child.type.hasSuffix("Block") {
                    output += "\n"
                }
            }
            indentLevel -= 1

            body = output
            output = oldOutput
        }

        output += "func \(name)(\(parameters)) -> Int {\n\(body)\(currentIndent)}\n"
    }

    private func generateCondition(_ node: ASTNode) {
        // Для простых условий с 3 компонентами (левый операнд, оператор, правый операнд)
        if node.children.count >= 3 {
            generateNode(node.children[0])
            output += " \(convertOperator(node.children[1].value ?? "")) "
            generateNode(node.children[2])
        }
        // Для булевых литералов
        else if let boolNode = node.children.first(where: { $0.type == "Boolean_literal" }) {
            output += boolNode.value.lowercased()
        }
        // Для других случаев
        else {
            for child in node.children {
                generateNode(child)
            }
        }
    }

    private func convertOperator(_ op: String) -> String {
        switch op {
        case "<>": return "!="
        case "=": return "=="
        case "mod": return "%"
        default: return op
        }
    }

    private func generateVariableDeclaration(_ node: ASTNode) {
        output += currentIndent

        let isMutable = node.children.contains(where: { $0.value == "mutable" })
        let keyword = isMutable ? "var" : "let"

        output += "\(keyword) \(node.value)"

        if let valueNode = node.children.first(where: { $0.type != "Type" && $0.type != "Modifier" }
        ) {
            output += " = "
            generateNode(valueNode)
        }

        // Для переменных не добавляем лишний перенос строки
        let nextNeedsSpace = node.children.contains { $0.type == "Body" }
        if !nextNeedsSpace {
            output += "\n"
        }
    }

    private func generateControlStructure(_ node: ASTNode, start: String) {
        output += currentIndent + start + " {\n"
        indentLevel += 1

        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            for child in bodyNode.children {
                generateNode(child)
            }
        }

        indentLevel -= 1
        output += currentIndent + "}\n"
    }

    private func generateClass(_ node: ASTNode) {
        output += "class \(node.value ?? "UnknownClass") {\n"
        indentLevel += 1
        
        // Собираем информацию о параметрах конструктора
        var constructorParams = [(name: String, type: String)]()
        if let paramsNode = node.children.first(where: { $0.type == "ConstructorParameters" }) {
            for param in paramsNode.children {
                let paramName = (param.value ?? "").capitalizedFirstLetter() // Первая буква заглавная
                let paramType = param.children.first(where: { $0.type == "Type" })?.value ?? "Any"
                constructorParams.append((name: paramName, type: paramType))
            }
        }
        
        // Генерация свойств с сохранением оригинального регистра
        for param in constructorParams {
            output += currentIndent + "let \(param.name): \(mapType(param.type))\n"
        }
        
        // Генерация инициализатора
        if !constructorParams.isEmpty {
            output += currentIndent + "init("
            let paramsStr = constructorParams.map { "\($0.name): \(mapType($0.type))" }.joined(separator: ", ")
            output += paramsStr + ") {\n"
            
            indentLevel += 1
            for param in constructorParams {
                output += currentIndent + "self.\(param.name) = \(param.name)\n"
            }
            indentLevel -= 1
            output += currentIndent + "}\n"
        }
        
        // Генерация методов
        if let membersNode = node.children.first(where: { $0.type == "Members" }) {
            for member in membersNode.children {
                if member.type == "MemberDefinition" && member.children.contains(where: { $0.type == "Body" }) {
                    generateMethod(member)
                }
            }
        }
        
        indentLevel -= 1
        output += "}\n"
    }

    private func generateInitializer(_ paramsNode: ASTNode) {
        output += currentIndent + "init("
        
        // Генерируем параметры конструктора с сохранением имен
        let params = paramsNode.children.map { param in
            let type = param.children.first?.value ?? "Any"
            return "\(param.value ?? "_"): \(mapType(type))"
        }.joined(separator: ", ")
        
        output += ") {\n"
        indentLevel += 1
        
        // Инициализация свойств с сохранением оригинальных имен
        for param in paramsNode.children {
            let paramName = param.value ?? ""
            output += currentIndent + "self.\(paramName) = \(paramName)\n"
        }
        
        indentLevel -= 1
        output += currentIndent + "}\n"
    }

    private func generateProperty(_ node: ASTNode) {
        // Сохраняем оригинальное имя свойства (с заглавной буквы)
        let propertyName = node.value ?? "property"
        output += currentIndent + "let \(propertyName): "
        
        // Определяем тип свойства
        if let fieldNode = node.children.first(where: { $0.type == "Field" }) {
            // Если есть тип в Field, используем его
            if let typeNode = fieldNode.children.first(where: { $0.type == "Type" }) {
                output += mapType(typeNode.value)
            } else {
                output += "Any" // Тип по умолчанию
            }
        } else {
            output += "Any"
        }
        
        output += "\n"
    }

    private func generateMethod(_ node: ASTNode) {
        let methodName = node.value ?? "method"
        output += currentIndent + "func \(methodName)("
        
        // Параметры метода
        if let paramsNode = node.children.first(where: { $0.type == "MethodParameters" }) {
            let params = paramsNode.children.map { param in
                let type = param.children.first?.value ?? "Any"
                return "\(param.value ?? "_"): \(mapType(type))"
            }.joined(separator: ", ")
            
            output += params
        }
        
        output += ") {\n"
        indentLevel += 1
        
        // Тело метода с заменой this на self
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            for child in bodyNode.children {
                generateNode(child)
                if !child.type.hasPrefix("If") && !child.type.hasPrefix("For") && 
                !child.type.hasPrefix("While") && child.type != "Body" {
                    output += "\n"
                }
            }
        }
        
        indentLevel -= 1
        output += currentIndent + "}\n"
    }

    private func generateMember(_ node: ASTNode) {
        output += currentIndent

        if node.children.contains(where: { $0.type == "MethodParameters" }) {
            // Метод
            output += "func \(node.value ?? "method")("

            // Параметры метода
            if let paramsNode = node.children.first(where: { $0.type == "MethodParameters" }) {
                let params = paramsNode.children.map { param in
                    let type = param.children.first?.value ?? "Any"
                    return "\(param.value ?? "_"): \(mapType(type))"
                }.joined(separator: ", ")

                output += params
            }

            output += ")"

            // Возвращаемый тип
            if let bodyNode = node.children.first(where: { $0.type == "Body" }),
                let lastStatement = bodyNode.children.last,
                lastStatement.type == "Return"
            {
                output += " -> \(inferReturnType(lastStatement))"
            }

            output += " {\n"
            indentLevel += 1

            // Тело метода
            if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
                for child in bodyNode.children {
                    generateNode(child)
                    if !child.type.hasPrefix("If") && !child.type.hasPrefix("For")
                        && !child.type.hasPrefix("While") && child.type != "Body"
                    {
                        output += "\n"
                    }
                }
            }

            indentLevel -= 1
            output += "\(currentIndent)}\n"
        } else {
            // Поле класса
            output += "let \(node.value ?? "field")"

            if let fieldNode = node.children.first(where: { $0.type == "Field" }) {
                output += " = "
                generateNode(fieldNode)
            }

            output += "\n"
        }
    }

    // MARK: - Control Flow

    private func generateIfStatement(_ node: ASTNode) {
        output += currentIndent + "if "

        // Генерируем условие
        if let conditionNode = node.children.first(where: { $0.type == "Condition" }) {
            generateNode(conditionNode)
        }

        output += " {\n"

        // Обрабатываем ThenBlock
        if let thenBlock = node.children.first(where: { $0.type == "ThenBlock" }) {
            generateNode(thenBlock)
        }

        output += currentIndent + "}"

        // Обрабатываем ElifStatement
        for child in node.children {
            if child.type == "ElifStatement" {
                output += " else if "
                if let elifCondition = child.children.first(where: { $0.type == "Condition" }) {
                    generateNode(elifCondition)
                }
                output += " {\n"

                if let elifThenBlock = child.children.first(where: { $0.type == "ThenBlock" }) {
                    generateNode(elifThenBlock)
                }

                output += currentIndent + "}"
            }
        }

        // Обрабатываем ElseBlock
        if let elseBlock = node.children.first(where: { $0.type == "ElseBlock" }) {
            output += " else {\n"
            generateNode(elseBlock)
            output += currentIndent + "}"
        }

        output += "\n"
    }

    private func generateWhileStatement(_ node: ASTNode) {
        output += currentIndent + "while "

        // Обрабатываем условие
        if let conditionNode = node.children.first(where: { $0.type == "Condition" }) {
            generateCondition(conditionNode)
        } else if let boolNode = node.children.first(where: { $0.type == "Boolean_literal" }) {
            output += boolNode.value.lowercased()
        } else {
            output += "true /* no condition found */"
        }

        output += " {\n"

        // Обрабатываем тело цикла
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            indentLevel += 1
            for child in bodyNode.children {
                generateNode(child)
            }
            indentLevel -= 1
        }

        output += currentIndent + "}\n"
    }

    private func generateForInStatement(_ node: ASTNode) {
        output += currentIndent + "for "
        
        // 1. Сначала находим идентификатор итератора
        guard let identifierNode = node.children.first(where: { $0.type == "Identifier" }) else {
            output += "item in [] {\n" // fallback если не нашли итератор
            indentLevel += 1
            if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
                for child in bodyNode.children {
                    generateNode(child)
                }
            }
            indentLevel -= 1
            output += currentIndent + "}\n"
            return
        }
        
        output += identifierNode.value + " in "
        
        // 2. Затем проверяем Range или коллекцию
        if let rangeNode = node.children.first(where: { $0.type == "Range" }) {
            // Обработка диапазона (1..5)
            let components = rangeNode.value.components(separatedBy: "..")
            if components.count == 2 {
                output += "\(components[0])...\(components[1])"
            }
        } else {
            // Ищем коллекцию (исключая сам идентификатор итератора)
            if let collectionNode = node.children.first(where: { 
                $0.type == "Identifier" && $0.value != identifierNode.value 
            }) {
                generateNode(collectionNode)
            } else if let collectionExpr = node.children.first(where: { 
                $0.type != "Identifier" && $0.type != "Body" && $0.type != "Range" 
            }) {
                generateNode(collectionExpr)
            } else {
                output += "[]" // fallback если коллекция не найдена
            }
        }
        
        // 3. Генерация тела цикла
        output += " {\n"
        indentLevel += 1
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            for child in bodyNode.children {
                generateNode(child)
            }
        }
        indentLevel -= 1
        output += currentIndent + "}\n"
    }

    private func generateForToStatement(_ node: ASTNode) {
        output += currentIndent + "for "

        // Идентификатор цикла
        guard let identifierNode = node.children.first(where: { $0.type == "Identifier" }) else {
            output += "/* missing identifier */ in 1...1 {\n"
            return
        }
        output += identifierNode.value + " in "

        // Начальное значение
        if let startValue = node.children.first(where: { $0.type == "StartValue" }),
            let valueNode = startValue.children.first(where: { $0.type == "Value" })
        {
            output += valueNode.value
        } else {
            output += "1"
        }

        // Конечное значение
        output += "..."
        if let endValue = node.children.first(where: { $0.type == "EndValue" }),
            let valueNode = endValue.children.first(where: { $0.type == "Value" })
        {
            output += valueNode.value
        } else {
            output += "1"
        }

        // Тело цикла
        output += " {\n"
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            indentLevel += 1
            for child in bodyNode.children {
                generateNode(child)
            }
            indentLevel -= 1
        }
        output += currentIndent + "}\n"
    }

    // MARK: - Expressions

    private func generateFunctionCall(_ node: ASTNode) {
        output += node.value ?? ""
        output += "("

        if let argsNode = node.children.first(where: { $0.type == "Arguments" }) {
            for (index, arg) in argsNode.children.enumerated() {
                if index > 0 { output += ", " }
                generateNode(arg.children.first ?? arg)  // Обрабатываем Argument
            }
        }

        output += ")"
    }

    private func generateBinaryOp(_ node: ASTNode) {
        guard node.children.count >= 2 else {
            output += node.value ?? ""
            return
        }

        let op = node.value ?? ""
        let swiftOp = convertOperator(op)

        generateNode(node.children[0])
        output += " \(swiftOp) "
        generateNode(node.children[1])
    }

    private func generateAssignment(_ node: ASTNode) {
        output += currentIndent

        // Цель присваивания (левая часть)
        output += node.value ?? ""  // Имя переменной (n)
        output += " = "

        // Значение (правая часть)
        if node.children.count > 0 {
            // Если есть дочерние узлы, генерируем их
            generateNode(node.children[0])
        } else if let binaryOpNode = node.children.first(where: { $0.type == "BinaryOp" }) {
            // Обработка случая с бинарной операцией
            generateBinaryOp(binaryOpNode)
        }

        output += "\n"
    }

    private func generateReturn(_ node: ASTNode) {
        output += currentIndent + "return "
        if let child = node.children.first {
            // Убираем лишний Assignment из Return
            if child.type == "Assignment" {
                generateNode(child.children.first ?? child)
            } else {
                generateNode(child)
            }
        }
        output += "\n"
    }

    private func generatePrint(_ node: ASTNode, newline: Bool) {
        output += currentIndent + "print("

        if let stringNode = node.children.first(where: { $0.type == "InterpolatedString" }) {
            let format = stringNode.value
            var swiftFormat = format
            
            // 1. Заменяем this. на self.
            swiftFormat = swiftFormat.replacingOccurrences(of: "this.", with: "self.")
            
            // 2. Обрабатываем выражения внутри {} и преобразуем имена свойств к lowercase
            let pattern = "\\{([^}]+)\\}"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(
                    in: swiftFormat, range: NSRange(location: 0, length: swiftFormat.utf16.count))

                for match in matches.reversed() {
                    let matchRange = match.range(at: 1)
                    if matchRange.location != NSNotFound,
                    let range = Range(matchRange, in: swiftFormat) {
                        let expression = String(swiftFormat[range])
                        
                        // Разбиваем выражение на части (для обработки цепочек свойств)
                        let parts = expression.components(separatedBy: ".")
                        var processedParts = [String]()
                        
                        for (index, part) in parts.enumerated() {
                            if index == 0 {
                                // Первую часть (после self.) приводим к lowercase
                                let firstCharLowercased = part.prefix(1).lowercased() + part.dropFirst()
                                processedParts.append(firstCharLowercased)
                            } else {
                                // Остальные части оставляем как есть (если это методы или другие свойства)
                                processedParts.append(part)
                            }
                        }
                        
                        let processedExpression = processedParts.joined(separator: ".")
                        if let expressionRange = Range(match.range(at: 0), in: swiftFormat) {
                            swiftFormat.replaceSubrange(
                                expressionRange,
                                with: "\\(\(processedExpression))"
                            )
                        }
                    }
                }
            }
            
            output += swiftFormat
        } else if let stringNode = node.children.first(where: { $0.type == "StringLiteral" }) {
            output += stringNode.value
        }

        output += newline ? ")" : ", terminator: \"\")"
        output += "\n"
    }

    private func generateArrayAccess(_ node: ASTNode) {
        generateNode(node.children[0])  // массив
        output += "["
        generateNode(node.children[1])  // индекс
        output += "]"
    }

    private func generatePropertyAccess(_ node: ASTNode) {
        if node.value == "this" {
            output += "self."
        } else {
            let propertyName = (node.value ?? "").capitalizedFirstLetter() // Первая буква заглавная
            output += propertyName
        }
    }

    private func generateArrayOrList(_ node: ASTNode) {
        output += "["
        for (index, child) in node.children.enumerated() {
            if index > 0 { output += ", " }
            generateNode(child)
        }
        output += "]"
    }

    // MARK: - Helpers

    private func mapType(_ fsharpType: String) -> String {
        // Удаляем возможные пробелы и приводим к lowercase
        let cleanedType = fsharpType.trimmingCharacters(in: .whitespaces).lowercased()


        // Проверяем generic типы
        if cleanedType.contains("<") {
            let baseType = String(cleanedType.prefix(upTo: cleanedType.firstIndex(of: "<")!))
            let innerTypes =
                cleanedType
                .components(separatedBy: "<")[1]
                .replacingOccurrences(of: ">", with: "")
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map(mapType)
                .joined(separator: ", ")

            if let swiftBase = typeMap[baseType] {
                return "\(swiftBase)<\(innerTypes)>"
            }
            return "\(baseType.capitalized)<\(innerTypes)>"
        }

        // Простые типы
        return typeMap[cleanedType] ?? fsharpType.capitalized
    }

    private func inferReturnType(_ returnNode: ASTNode) -> String {
        guard let returnExpr = returnNode.children.first else { return "Void" }

        switch returnExpr.type {
        case "Number":
            return "Int"
        case "Float_number":
            return "Double"
        case "String_literal":
            return "String"
        case "Boolean_literal":
            return "Bool"
        case "ArrayOrList":
            let childType = returnExpr.children.first.map { inferReturnType($0) } ?? "Any"
            return "[\(childType)]"
        case "FunctionCall":
            // Предполагаем, что возвращаемый тип совпадает с именем функции
            return returnExpr.value.capitalized
        default:
            return "Any"
        }
    }

    private func generateSetDeclaration(_ node: ASTNode) {
        output += "Set(["
        for (index, child) in node.children.enumerated() {
            if index > 0 { output += ", " }
            generateNode(child)
        }
        output += "])"
    }

    private func generateSequenceDeclaration(_ node: ASTNode) {
        if let rangeNode = node.children.first(where: { $0.type == "Range" }) {
            // Обработка seq {1..6}
            let components = rangeNode.value.components(separatedBy: "..")
            if components.count == 2 {
                output += "stride(from: \(components[0]), through: \(components[1]), by: 1)"
            } else {
                output += "[]"
            }
        } else {
            // Обработка seq {1; 2; 3}
            output += "["
            for (index, child) in node.children.enumerated() {
                if index > 0 { output += ", " }
                generateNode(child)
            }
            output += "]"
        }
    }

    private func generateListDeclaration(_ node: ASTNode) {
        output += "["
        for (index, child) in node.children.enumerated() {
            if index > 0 { output += ", " }
            generateNode(child)
        }
        output += "]"
    }

    private func generateMapDeclaration(_ node: ASTNode) {
        output += "["
        for (index, child) in node.children.enumerated() {
            if index > 0 { output += ", " }
            generateNode(child)
        }
        output += "]"
    }

    private func generateKeyValuePair(_ node: ASTNode) {
        guard node.children.count >= 2 else {
            output += ":\"\""
            return
        }
        generateNode(node.children[0])  // ключ
        output += ": "
        generateNode(node.children[1])  // значение
    }

    private func generateArrayDeclaration(_ node: ASTNode) {
        output += "["
        for (index, child) in node.children.enumerated() {
            if index > 0 { output += ", " }
            generateNode(child)
        }
        output += "]"
    }
}


private extension String {
    func capitalizedFirstLetter() -> String {
        guard !isEmpty else { return self }
        return prefix(1).capitalized + dropFirst()
    }
}