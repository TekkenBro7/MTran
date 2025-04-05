import CDispatch

import Foundation

class SemanticAnalyzer {
    private var symbolTable = [String: SymbolInfo]()
    private var currentScope = "global"
    private var errors: [String] = []
    private var reportedErrors = Set<String>()

    struct SymbolInfo {
        let name: String
        let type: String
        let isMutable: Bool
        let scope: String
        let line: Int
        var isFunction: Bool
        var parameters: [ParameterInfo]?

        struct ParameterInfo {
            let name: String
            var type: String
        }
    }

    func analyze(node: ASTNode) -> [String] {
        errors.removeAll()
        visit(node: node)
        return errors
    }

    private func visit(node: ASTNode) {
        switch node.type {
        case "Program":
            visitProgram(node)
        case "FunctionDeclaration":
            visitFunctionDeclaration(node)
        case "VariableDeclaration":
            visitVariableDeclaration(node)
        case "Assignment":
            visitAssignment(node)
        case "FunctionCall":
            visitFunctionCall(node)
        case "IfStatement":
            visitIfStatement(node)
        case "WhileStatement":
            visitWhileStatement(node)
        case "ForInStatement", "ForToStatement":
            visitForStatement(node)
        case "Class":
            visitClassDeclaration(node)
        case "BinaryOp":
            visitBinaryOperation(node)
        case "Return":
            visitReturn(node)
        default:
            // Всегда посещаем дочерние узлы
            for child in node.children {
                visit(node: child)
            }
            // Добавляем проверку типов для текущего узла
            _ = inferType(node: node)
        }
    }

    private func visitProgram(_ node: ASTNode) {
        for child in node.children {
            visit(node: child)
        }
    }

    private func visitFunctionDeclaration(_ node: ASTNode) {
        guard let nameNode = node.children.first(where: { $0.type == "FunctionName" }) else {
            addError("Не найдено имя функции", line: node.line)
            return
        }

        let functionName = nameNode.value
        let previousScope = currentScope
        currentScope = functionName

        // Проверяем, не объявлена ли уже функция с таким именем
        if symbolTable[functionName] != nil {
            addError("Повторное объявление функции '\(functionName)'", line: node.line)
        }

        // Создаем временный массив для параметров
        var parameters: [SymbolInfo.ParameterInfo] = []
        if let paramsNode = node.children.first(where: { $0.type == "Parameters" }) {
            for paramNode in paramsNode.children {
                // По умолчанию ставим int для параметров в арифметических операциях
                let paramType = paramNode.children.first?.value ?? "int"

                parameters.append(
                    SymbolInfo.ParameterInfo(
                        name: paramNode.value,
                        type: paramType  // тип по умолчанию
                    ))

                // Добавляем параметры в таблицу символов
                symbolTable[paramNode.value] = SymbolInfo(
                    name: paramNode.value,
                    type: paramType,
                    isMutable: false,
                    scope: functionName,
                    line: node.line,
                    isFunction: false
                )
            }
        }

        // Добавляем функцию в таблицу символов
        symbolTable[functionName] = SymbolInfo(
            name: functionName,
            type: "function",
            isMutable: false,
            scope: previousScope,
            line: node.line,
            isFunction: true,
            parameters: parameters
        )

        // Определяем возвращаемый тип функции
        var returnType = "unknown"
        if let bodyNode = node.children.first(where: { $0.type == "Body" }) {
            // Ищем последний return statement
            if let returnNode = bodyNode.children.last(where: { $0.type == "Return" }) {
                if let returnExpr = returnNode.children.first {
                    returnType = inferType(node: returnExpr)
                }
            }
            // Если нет явного return, берем тип последнего выражения
            else if let lastExpr = bodyNode.children.last {
                returnType = inferType(node: lastExpr)
            }

            // Обновляем информацию о функции с возвращаемым типом
            if var functionInfo = symbolTable[functionName] {
                // Добавляем возвращаемый тип как последний "параметр"
                functionInfo.parameters?.append(
                    SymbolInfo.ParameterInfo(name: "return", type: returnType))
                symbolTable[functionName] = functionInfo
            }

            // Проверяем тело функции
            for statement in bodyNode.children {
                visit(node: statement)
            }
        }

        currentScope = previousScope
    }

    private func visitVariableDeclaration(_ node: ASTNode) {
        let varName = node.value

        // Проверяем, объявлена ли переменная в текущей области видимости
        if let existingSymbol = symbolTable[varName], existingSymbol.scope == currentScope {
            addError("Повторное объявление переменной '\(varName)'", line: node.line)
            return
        }

        let isMutable = node.children.contains { $0.type == "Modifier" && $0.value == "mutable" }

        // Определяем тип из выражения инициализации
        var varType = "unknown"
        if let exprNode = node.children.last(where: { $0.type != "Type" && $0.type != "Modifier" })
        {
            varType = inferType(node: exprNode)
            Logger2.log("Определен тип '\(varType)' для переменной '\(varName)' из выражения")

            // Специальная обработка для массивов
            if exprNode.type == "ArrayDeclaration" {
                // Убедимся, что тип массива правильно определен
                if varType == "unknown" {
                    varType = "array<unknown>"
                }
                Logger2.log("Уточнен тип массива для '\(varName)': \(varType)")
            }
        }

        // Если тип указан явно (: тип), используем его
        if let typeNode = node.children.first(where: { $0.type == "Type" }) {
            varType = typeNode.value
            Logger2.log("Тип переменной '\(varName)' явно указан как '\(varType)'")
        }

        // Добавляем в symbolTable
        symbolTable[varName] = SymbolInfo(
            name: varName,
            type: varType,  // Теперь здесь будет конкретный тип
            isMutable: isMutable,
            scope: currentScope,
            line: node.line,
            isFunction: false
        )

        if let exprNode = node.children.last, exprNode.type != "Type" && exprNode.type != "Modifier"
        {
            // Принудительно посещаем выражение, чтобы выявить ошибки
            visit(node: exprNode)
            let exprType = inferType(node: exprNode)
            // ... остальные проверки ...
        }

        Logger2.log("Добавлена переменная '\(varName)' типа '\(varType)' в symbolTable")
    }

    private func visitAssignment(_ node: ASTNode) {
        let varName = node.value

        // Проверяем, объявлена ли переменная
        guard let symbol = symbolTable[varName] else {
            addError("Использование необъявленной переменной '\(varName)'", line: node.line)
            return
        }

        // Проверяем, является ли переменная изменяемой
        if !symbol.isMutable {
            addError("Попытка изменить неизменяемую переменную '\(varName)'", line: node.line)
        }

        // Проверяем тип присваиваемого выражения
        if node.children.count > 0 {
            let exprType = inferType(node: node.children[0])
            if symbol.type != "unknown" && exprType != "unknown" && symbol.type != exprType {
                addError(
                    "Несоответствие типов: ожидается '\(symbol.type)', получено '\(exprType)'",
                    line: node.line)
            }
        }
    }

    private func visitFunctionCall(_ node: ASTNode) {
        let funcName = node.value

        // Проверяем, объявлена ли функция
        guard let symbol = symbolTable[funcName], symbol.isFunction else {
            addError("Вызов необъявленной функции '\(funcName)'", line: node.line)
            return
        }

        // Проверяем аргументы
        if let argsNode = node.children.first(where: { $0.type == "Arguments" }) {
            let argsCount = argsNode.children.count
            let paramsCount = symbol.parameters?.count ?? 0

            // Если возвращаемый тип учтён в parameters, вычтите 1:
            let effectiveParamsCount = symbol.isFunction ? paramsCount - 1 : paramsCount

            if argsCount != effectiveParamsCount {
                addError(
                    "Несоответствие количества аргументов: ожидается \(effectiveParamsCount), получено \(argsCount)",
                    line: node.line)
            } else {
                // Проверяем типы аргументов
                for (i, argNode) in argsNode.children.enumerated() {
                    if let paramType = symbol.parameters?[i].type {
                        let argType = inferType(node: argNode)
                        if paramType != "unknown" && argType != paramType {
                            addError(
                                "Несоответствие типа аргумента \(i+1): ожидается '\(paramType)', получено '\(argType)'",
                                line: argNode.line)
                        }
                    }
                }
            }
        } else if symbol.parameters?.count ?? 0 > 0 {
            addError(
                "Функция '\(funcName)' ожидает аргументы, но они не предоставлены", line: node.line)
        }
    }

    private func visitIfStatement(_ node: ASTNode) {
        Logger2.log("Начало анализа IfStatement в строке \(node.line)")
        // Проверяем условие
        if let conditionNode = node.children.first {
            Logger2.log(
                "Анализ условия if: тип узла = \(conditionNode.type), значение = \(conditionNode.value)"
            )
            let conditionType = inferType(node: conditionNode)
            Logger2.log("Определенный тип условия: \(conditionType)")
            if conditionType != "bool" {
                addError(
                    "Условие if должно быть булевым, получено '\(conditionType)'", line: node.line)
                Logger2.log("Ошибка: условие if имеет небулев тип '\(conditionType)'")
            }
        }

        // Проверяем тело
        if node.children.count > 1 {
            let bodyNode = node.children[1]
            for statement in bodyNode.children {
                visit(node: statement)
            }
        }
        Logger2.log("Завершение анализа IfStatement")
    }

    private func visitWhileStatement(_ node: ASTNode) {
        Logger2.log("Начало анализа WhileStatement в строке \(node.line)")

        guard let conditionNode = node.children.first else {
            addError("Отсутствует условие в while", line: node.line)
            Logger2.log("Ошибка: отсутствует условие в while")
            return
        }

        // Логгируем информацию о условии
        Logger2.log(
            "Анализ условия while: тип узла = \(conditionNode.type), дети = \(conditionNode.children.map { $0.type })"
        )

        // Определяем тип условия
        let conditionType = inferType(node: conditionNode)
        Logger2.log("Тип условия while: \(conditionType)")

        // Проверяем тип условия
        if conditionType != "bool" {
            addError(
                "Условие while должно быть булевым, получено '\(conditionType)'",
                line: conditionNode.line)
            Logger2.log("Обнаружена ошибка: небулев тип в условии while")
        }

        // Проверяем тело цикла
        if node.children.count > 1 {
            Logger2.log("Начало анализа тела while (строк: \(node.children[1].children.count))")
            let bodyNode = node.children[1]
            for statement in bodyNode.children {
                visit(node: statement)
            }
        }

        Logger2.log("Завершение анализа WhileStatement")
    }

    private func visitForStatement(_ node: ASTNode) {
        if node.type == "ForToStatement" && node.children.count >= 3 {
            let iteratorNode = node.children[0]  // i
            let forScope = "for_\(node.line)"
            symbolTable[iteratorNode.value] = SymbolInfo(
                name: iteratorNode.value,
                type: "int",
                isMutable: true,
                scope: forScope,
                line: node.line,
                isFunction: false
            )
        }

        // Для for..in проверяем итератор
        if node.type == "ForInStatement" && node.children.count >= 2 {
            let collectionNode = node.children[1]
            let collectionType = inferType(node: collectionNode)

            // Специальная обработка для диапазонов
            if collectionType == "range" {
                // Для диапазонов не нужно выдавать ошибку
            } else if collectionType != "range" && !collectionType.hasPrefix("seq<")
                && !collectionType.hasPrefix("list<")
                && !collectionType.hasPrefix("array<") && collectionType != "string"
                && collectionType != "unknown"  // Не выдаем ошибку для еще неопределенных типов
            {
                addError(
                    "Цикл for..in ожидает коллекцию, получено '\(collectionType)'", line: node.line)
            }
        }

        // Проверяем тело цикла
        if let bodyNode = node.children.last {
            let previousScope = currentScope
            let forScope = "for_\(node.line)"
            currentScope = forScope

            // Для for..in добавляем переменную-итератор в таблицу символов
            if node.type == "ForInStatement" && node.children.count >= 1 {
                let iteratorNode = node.children[0]
                // Определяем тип итератора на основе типа коллекции
                let collectionType =
                    node.children.count >= 2 ? inferType(node: node.children[1]) : "unknown"
                let iteratorType =
                    collectionType == "range"
                    ? "int"
                    : collectionType.hasPrefix("list<")
                        ? String(collectionType.dropFirst(5).dropLast())
                        : collectionType.hasPrefix("array<")
                            ? String(collectionType.dropFirst(6).dropLast()) : "unknown"

                symbolTable[iteratorNode.value] = SymbolInfo(
                    name: iteratorNode.value,
                    type: iteratorType,
                    isMutable: true,  // Переменные цикла делаем изменяемыми
                    scope: forScope,
                    line: node.line,
                    isFunction: false
                )
            }

            for statement in bodyNode.children {
                visit(node: statement)
            }

            symbolTable = symbolTable.filter { $0.value.scope != forScope }
            currentScope = previousScope
        }
    }

    private func checkArrayIndex(indexNode: ASTNode, arrayNode: ASTNode, line: Int) {
        let indexType = inferType(node: indexNode)

        // Проверяем, что индекс целочисленный
        if indexType != "int" {
            addError("Индекс массива должен быть целым числом, получено \(indexType)", line: line)
            return
        }

        // Проверяем, что индекс не отрицательный (если это числовой литерал)
        if indexNode.type == "Number", let indexValue = Int(indexNode.value), indexValue < 0 {
            addError("Индекс массива не может быть отрицательным", line: line)
            return
        }

        // Проверяем, что индекс не вещественный (если это числовой литерал)
        if indexNode.type == "Float_number" {
            addError("Индекс массива должен быть целым числом, получено вещественное", line: line)
            return
        }
    }

    private func visitClassDeclaration(_ node: ASTNode) {
        let className = node.value
        Logger2.log("Начало анализа класса \(className)")
        let previousScope = currentScope
        currentScope = className

        // Добавляем класс в таблицу символов
        symbolTable[className] = SymbolInfo(
            name: className,
            type: "class",
            isMutable: false,
            scope: previousScope,
            line: node.line,
            isFunction: false
        )

        // Обрабатываем параметры конструктора
        if let paramsNode = node.children.first(where: { $0.type == "Parameters" }) {
            for paramNode in paramsNode.children {
                let paramName = paramNode.value
                let paramType = paramNode.children.first?.value ?? "unknown"

                // Добавляем параметры как члены класса
                symbolTable["\(className).\(paramName)"] = SymbolInfo(
                    name: paramName,
                    type: paramType,
                    isMutable: false,
                    scope: className,
                    line: node.line,
                    isFunction: false
                )
            }
        }

        // Обрабатываем методы и свойства
        if let membersNode = node.children.first(where: { $0.type == "Members" }) {
            for member in membersNode.children {
                if member.type == "Member" {
                    let memberName = member.value
                    let memberType = inferType(node: member)

                    symbolTable["\(className).\(memberName)"] = SymbolInfo(
                        name: memberName,
                        type: memberType,
                        isMutable: true,  // Члены класса по умолчанию изменяемы
                        scope: className,
                        line: member.line,
                        isFunction: member.type == "FunctionDeclaration"
                    )
                }
                visit(node: member)
            }
        }

        currentScope = previousScope
    }

    private func visitBinaryOperation(_ node: ASTNode) {
        guard node.children.count == 2 else {
            addError("Бинарная операция требует два операнда", line: node.line)
            return
        }

        let leftType = inferType(node: node.children[0])
        let rightType = inferType(node: node.children[1])
        let op = node.value

        // Специальная проверка для строковой конкатенации
        if op == "+" {
            if leftType == "string" || rightType == "string" {
                if leftType != "string" || rightType != "string" {
                    addError(
                        "Конкатенация строк возможна только между строками. Нельзя сложить '\(leftType)' и '\(rightType)'",
                        line: node.line)
                    Logger2.log(
                        "Ошибка конкатенации: попытка сложить '\(leftType)' и '\(rightType)'")
                    return
                }
            }
        }

        // Проверка для арифметических операций
        if ["+", "-", "*", "/"].contains(op) {
            if !isNumericType(leftType) || !isNumericType(rightType) {
                addError(
                    "Арифметическая операция '\(op)' требует числовые типы, получено '\(leftType)' и '\(rightType)'",
                    line: node.line)
            }
        }
    }

    private func isNumericType(_ type: String) -> Bool {
        return type == "int" || type == "float"
    }

    private func visitReturn(_ node: ASTNode) {
        // Проверяем, что возвращаемое значение соответствует ожидаемому типу функции
        if let returnExpr = node.children.first {
            let returnType = inferType(node: returnExpr)

            if var functionSymbol = symbolTable[currentScope], functionSymbol.isFunction {
                // Если функция уже имеет указанный возвращаемый тип
                if let expectedType = functionSymbol.parameters?.last(where: { $0.name == "return" }
                )?.type,
                    expectedType != "unknown" && returnType != "unknown"
                        && expectedType != returnType
                {
                    addError(
                        "Несоответствие типа возвращаемого значения: ожидается '\(expectedType)', получено '\(returnType)'",
                        line: node.line)
                }
                // Если тип еще не определен, устанавливаем его
                else if functionSymbol.parameters?.last(where: { $0.name == "return" })?.type
                    == "unknown"
                {
                    if let index = functionSymbol.parameters?.lastIndex(where: {
                        $0.name == "return"
                    }) {
                        functionSymbol.parameters?[index].type = returnType
                        symbolTable[currentScope] = functionSymbol
                    }
                }
            }
        }
    }

    private func inferType(node: ASTNode) -> String {
        //   Logger2.log("Определение типа для узла \(node.type) со значением '\(node.value)'")
        switch node.type {
        case "ArrayDeclaration":
            if node.children.isEmpty {
                return "array<unknown>"
            }
            var elementType = "unknown"
            for child in node.children {
                let childType = inferType(node: child)
                if elementType == "unknown" {
                    elementType = childType
                } else if elementType != childType {
                    // Для разнородных массивов считаем тип unknown
                    elementType = "unknown"
                    break
                }
            }
            return "array<\(elementType)>"
        case "ArrayAccess":
            // Проверяем тип массива и индекс
            let arrayName = node.value
            guard let arraySymbol = symbolTable[arrayName] else {
                addError("Использование необъявленного массива '\(arrayName)'", line: node.line)
                return "unknown"
            }

            // Проверяем, что это действительно массив
            if !arraySymbol.type.hasPrefix("array<") && !arraySymbol.type.hasPrefix("list<") {
                addError("'\(arrayName)' не является массивом или списком", line: node.line)
            }

            // Проверяем индекс
            if let indexNode = node.children.first {
                checkArrayIndex(indexNode: indexNode, arrayNode: node, line: node.line)
            }

            // Возвращаем тип элементов массива
            if arraySymbol.type.hasPrefix("array<") || arraySymbol.type.hasPrefix("list<") {
                return String(arraySymbol.type.dropFirst(6).dropLast())
            }
            if arraySymbol.type.hasPrefix("list<") {
                return String(arraySymbol.type.dropFirst(5).dropLast())
            }
            return "unknown"
        case "Number":
            return "int"
        case "BinaryOp" where ["<", ">", "<=", ">=", "==", "!="].contains(node.value):
            return "bool"
        case "ListDeclaration":
            if node.children.isEmpty {
                return "list<unknown>"
            }
            var elementType = "unknown"
            for child in node.children {
                let childType = inferType(node: child)
                if elementType == "unknown" {
                    elementType = childType
                } else if elementType != childType {
                    // Для разнородных списков считаем тип unknown
                    elementType = "unknown"
                    break
                }
            }
            return "list<\(elementType)>"
        case "Condition":
            // Для условий сначала посещаем все дочерние узлы
            for child in node.children {
                visit(node: child)
            }

            // Если условие содержит оператор сравнения, возвращаем bool
            if node.children.contains(where: {
                $0.type == "Operator" && ["<", ">", "<=", ">=", "==", "!="].contains($0.value)
            }) {
                return "bool"
            }

            // Для простых условий возвращаем тип первого дочернего элемента
            return node.children.first.map { inferType(node: $0) } ?? "unknown"
        case "PropertyAccess":
            Logger2.log("Обработка PropertyAccess: \(node.value)")
            if node.children.count == 2 {
                let objectType = inferType(node: node.children[0])
                let propertyName = node.children[1].value
                let fullName = "\(objectType).\(propertyName)"

                Logger2.log("Поиск свойства \(fullName) в таблице символов")

                if let symbol = symbolTable[fullName] {
                    Logger2.log("Найдено свойство \(fullName) типа \(symbol.type)")
                    return symbol.type
                }
            }
            return "unknown"
        case "Range":
            return "range"
        case "Float_number":
            return "float"
        case "String_literal", "InterpolatedString":
            return "string"
        case "Char_literal":
            return "char"
        case "Boolean_literal":
            return "bool"
        case "Identifier":
            guard let symbol = symbolTable[node.value] else {
                addError("Использование необъявленной переменной '\(node.value)'", line: node.line)
                Logger2.log("Ошибка: переменная '\(node.value)' не найдена в symbolTable")
                return "unknown"
            }
            Logger2.log("Найден тип '\(symbol.type)' для переменной '\(node.value)'")
            return symbol.type
        case "BinaryOp":
            // Для операторов сравнения возвращаем bool
            if ["<", ">", "<=", ">=", "==", "!="].contains(node.value) {
                return "bool"
            }

            // Для арифметических операций определяем тип по операндам
            guard node.children.count == 2 else { return "unknown" }

            let leftType = inferType(node: node.children[0])
            let rightType = inferType(node: node.children[1])

            if node.value == "+" && leftType == "string" && rightType == "string" {
                return "string"
            }

            if ["+", "-", "*", "/"].contains(node.value) {
                if leftType == "float" || rightType == "float" {
                    return "float"
                }
                return "int"
            }

            return "unknown"
        case "FunctionCall":
            // Для простоты возвращаем тип возвращаемого значения функции
            // В реальной реализации нужно хранить информацию о возвращаемом типе функции
            return "unknown"
        case "ArrayOrList":
            return inferCollectionType(node: node)
        case "Map":
            return "Map<unknown, unknown>"
        case "Set":
            return "Set<unknown>"
        case "MemberAccess":
            if node.children.count == 2 {
                let objectType = inferType(node: node.children[0])
                let memberName = node.children[1].value

                // Попробуем найти член в таблице символов
                let fullName = "\(objectType).\(memberName)"
                if let symbol = symbolTable[fullName] {
                    return symbol.type
                }
            }
            return "unknown"
        default:
            return "unknown"
        }
    }

    private func inferBinaryOpType(node: ASTNode) -> String {
        guard node.children.count == 2 else { return "unknown" }

        let oper = node.value
        if ["==", "!=", "<", ">", "<=", ">="].contains(oper) {
            return "bool"
        }

        let leftType = inferType(node: node.children[0])
        let rightType = inferType(node: node.children[1])
        let op = node.value

        if op == "+" && leftType == "string" && rightType == "string" {
            return "string"
        }

        // Для арифметических операций тип результата - тип операндов
        if ["+", "-", "*", "/"].contains(op) && isNumericType(leftType) && isNumericType(rightType)
        {
            if leftType == rightType {
                return leftType
            } else if leftType == "float" || rightType == "float" {
                return "float"
            } else if leftType == "int" && rightType == "int" {
                return "int"
            }
        }

        // Для сравнений тип результата всегда bool
        if ["==", "!=", "<", ">", "<=", ">="].contains(op) {
            return "bool"
        }

        // Для логических операций тип результата bool
        if ["&&", "||"].contains(op) {
            return "bool"
        }

        return "unknown"
    }

    private func inferCollectionType(node: ASTNode) -> String {
        guard !node.children.isEmpty else { return "list<unknown>" }

        var elementType = "unknown"
        for child in node.children {
            let childType = inferType(node: child)
            if elementType == "unknown" {
                elementType = childType
            } else if elementType != childType {
                elementType = "unknown"
                break
            }
        }

        return node.value == "[" ? "list<\(elementType)>" : "array<\(elementType)>"
    }

    private func isOperationValid(op: String, leftType: String, rightType: String) -> Bool {
        // Проверяем допустимость операции для данных типов
        let numericTypes = ["int", "float"]
        let comparableTypes = ["int", "float", "string", "char", "bool"]

        switch op {
        case "+", "-", "*", "/":
            return numericTypes.contains(leftType) && numericTypes.contains(rightType)
        case "==", "!=":
            return leftType == rightType && comparableTypes.contains(leftType)
        case "<", ">", "<=", ">=":
            return comparableTypes.contains(leftType) && comparableTypes.contains(rightType)
                && leftType != "bool" && rightType != "bool"
        case "&&", "||":
            return leftType == "bool" && rightType == "bool"
        default:
            return false
        }
    }

    private func addError(_ message: String, line: Int) {
        let errorKey = "\(line):\(message)"  // Уникальный ключ для ошибки
        if !reportedErrors.contains(errorKey) {
            errors.append("Семантическая ошибка в строке \(line): \(message)")
            reportedErrors.insert(errorKey)
        }
    }
}
