@attached(member, names: named(init))
@attached(extension, conformances: ZWBCodable)
public macro ZWB_Codable() = #externalMacro(module: "ZWB_CodableMacros", type: "ZWBCodableMacro")
