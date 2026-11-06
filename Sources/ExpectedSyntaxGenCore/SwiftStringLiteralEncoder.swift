enum SwiftStringLiteralEncoder {
  static func encode(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22:
        result += "\\\""
      case 0x5C:
        result += "\\\\"
      case 0x20...0x21, 0x23...0x5B, 0x5D...0x7E:
        result.unicodeScalars.append(scalar)
      default:
        result += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
      }
    }
    result += "\""
    return result
  }
}
