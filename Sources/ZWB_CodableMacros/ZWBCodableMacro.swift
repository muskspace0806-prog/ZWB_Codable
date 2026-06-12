import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ZWBCodableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            return []
        }

        if hasZeroArgumentInitializer(in: declaration) {
            return []
        }

        return [
            DeclSyntax("required init() {}")
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        if alreadyConformsToZWBCodable(declaration) {
            return []
        }

        let extensionDecl: DeclSyntax = "extension \(type.trimmed): ZWBCodable {}"
        guard let extensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [extensionDecl]
    }

    private static func hasZeroArgumentInitializer(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { member in
            guard let initializer = member.decl.as(InitializerDeclSyntax.self) else {
                return false
            }
            return initializer.signature.parameterClause.parameters.isEmpty
        }
    }

    private static func alreadyConformsToZWBCodable(_ declaration: some DeclGroupSyntax) -> Bool {
        let inheritanceClause: InheritanceClauseSyntax?
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            inheritanceClause = classDecl.inheritanceClause
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            inheritanceClause = structDecl.inheritanceClause
        } else {
            inheritanceClause = nil
        }

        return inheritanceClause?.inheritedTypes.contains { inheritedType in
            inheritedType.type.trimmedDescription == "ZWBCodable"
        } ?? false
    }
}

@main
struct ZWBCodablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ZWBCodableMacro.self
    ]
}
