import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// Macro that turns a type into a dependency injection graph.
public struct DependencyGraphMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        let isClass = declaration.is(ClassDeclSyntax.self)
        let isStruct = declaration.is(StructDeclSyntax.self)
        guard isClass || isStruct else { return [] }
        
        let members = declaration.memberBlock.members
        
        // Inherit access level
        let accessLevel = declaration.modifiers.compactMap { mod in
            let text = mod.name.text
            return (text == "public" || text == "internal" || text == "open") ? text : nil
        }.first ?? ""
        let prefix = accessLevel.isEmpty ? "" : "\(accessLevel) "
        
        // Helper to extract scope from an attribute
        func extractScope(from attr: AttributeSyntax) -> String {
            guard let args = attr.arguments?.as(LabeledExprListSyntax.self),
                  let scopeArg = args.first(where: { $0.label?.text == "scope" }) else {
                return ".singleton"
            }
            return scopeArg.expression.trimmedDescription
        }
        
        // 1. Discover stored properties (not provided or implemented)
        var storedProperties: [(String, String)] = []
        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            if varDecl.attributes.contains(where: { 
                $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription.contains("Implemented") ?? false 
            }) { continue }
            
            for binding in varDecl.bindings {
                guard binding.accessorBlock == nil else { continue }
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
                if identifier == "container" { continue }
                guard let type = binding.typeAnnotation?.type.trimmedDescription else { continue }
                storedProperties.append((identifier, type))
            }
        }
        
        // 2. Discover provider methods
        let methodProviders = members.compactMap { member -> (String, String, String)? in
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { return nil }
            let name = funcDecl.name.text
            guard name.hasPrefix("provide") else { return nil }
            guard let returnType = funcDecl.signature.returnClause?.type.trimmedDescription else { return nil }
            
            let scope = funcDecl.attributes.compactMap { attr -> String? in
                guard let attr = attr.as(AttributeSyntax.self),
                      attr.attributeName.trimmedDescription.contains("Provider") else { return nil }
                return extractScope(from: attr)
            }.first ?? ".singleton"
            
            return (name, returnType, scope)
        }
        
        // 3. Discover @Implemented properties
        let implementedRegistrations = members.compactMap { member -> (String, String, String, String)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard let attr = varDecl.attributes.compactMap({ $0.as(AttributeSyntax.self) })
                .first(where: { $0.attributeName.trimmedDescription.contains("Implemented") }) else { return nil }
            
            guard let args = attr.arguments?.as(LabeledExprListSyntax.self),
                  let firstArg = args.first(where: { $0.label?.text == "by" }) else { return nil }
            
            let implementationType = firstArg.expression.trimmedDescription.replacingOccurrences(of: ".self", with: "")
            let scope = extractScope(from: attr)
            
            guard let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let protocolType = binding.typeAnnotation?.type.trimmedDescription else { return nil }
            
            return (identifier, protocolType, implementationType, scope)
        }
        
        // 4. Storage container
        let containerDecl: DeclSyntax = "\(raw: prefix)let container = ServiceContainer()"
        
        // 5. Initializer
        let initParams = storedProperties.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
        let initAssignments = storedProperties.map { "self.\($0.0) = \($0.0)" }.joined(separator: "\n        ")
        
        let hasMethodProviders = !methodProviders.isEmpty
        let captureSetup = (hasMethodProviders && isStruct) ? "let _graph = self" : ""
        let capturedName = (hasMethodProviders && isStruct) ? "_graph" : "self"
        let captureList = (hasMethodProviders && isClass) ? "[unowned self]" : ""
        
        let methodRegistrationLines = methodProviders.map { (name, type, scope) in
            "self.container.register(\(type).self, scope: \(scope)) { \(captureList) (_: ServiceContainer) in \(capturedName).\(name)() }"
        }.joined(separator: "\n        ")
        
        let implementedRegistrationLines = implementedRegistrations.map { (_, protocolType, implementationType, scope) in
            "self.container.register(\(protocolType).self, scope: \(scope)) { _ in \(implementationType)() }"
        }.joined(separator: "\n        ")
        
        var initBodyLines: [String] = []
        if !initAssignments.isEmpty { initBodyLines.append(initAssignments) }
        if !captureSetup.isEmpty { initBodyLines.append(captureSetup) }
        if !methodRegistrationLines.isEmpty { initBodyLines.append(methodRegistrationLines) }
        if !implementedRegistrationLines.isEmpty { initBodyLines.append(implementedRegistrationLines) }
        
        initBodyLines.append("self.makeShared()")
        
        let initBody = initBodyLines.joined(separator: "\n        ")
        
        let initDecl: DeclSyntax = """
        \(raw: prefix)init(\(raw: initParams)) {
            \(raw: initBody)
        }
        """
        
        // 6. Computed properties
        let methodPropertyDecls = methodProviders.map { (name, type, _) -> DeclSyntax in
            let propertyName = name.replacingOccurrences(of: "provide", with: "").firstLowercased()
            return """
            \(raw: prefix)var \(raw: propertyName): \(raw: type) {
                self.container.resolve(\(raw: type).self)
            }
            """
        }
        
        // 7. Run method
        let runDecl: DeclSyntax = """
        \(raw: prefix)func run<T>(_ operation: () throws -> T) rethrows -> T {
            try ServiceContainer.$active.withValue(self.container) {
                try operation()
            }
        }
        """
        
        // 8. makeShared method
        let makeSharedDecl: DeclSyntax = """
        \(raw: prefix)func makeShared() {
            self.container.makeShared()
        }
        """
        
        var allDecls: [DeclSyntax] = [containerDecl, initDecl, runDecl, makeSharedDecl]
        allDecls.append(contentsOf: methodPropertyDecls)
        
        return allDecls
    }
}

public struct ProviderMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { return [] }
}

public struct ImplementedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let type = binding.typeAnnotation?.type.trimmedDescription else {
            return []
        }
        return ["get { self.container.resolve(\(raw: type).self) }"]
    }
}

public struct ServiceMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let type = binding.typeAnnotation?.type.trimmedDescription else {
            return []
        }
        return [
            """
            get {
                let resolvedContainer = ServiceContainer.active ?? .shared
                return resolvedContainer.resolve(\(raw: type).self)
            }
            """
        ]
    }
}

@main
struct HummingbirdCompilerPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DependencyGraphMacro.self,
        ProviderMacro.self,
        ImplementedMacro.self,
        ServiceMacro.self
    ]
}

extension String {
    func firstLowercased() -> String {
        guard let first = first else { return self }
        return String(first).lowercased() + dropFirst()
    }
}
