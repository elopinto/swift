// REQUIRES: swift_swift_parser

// This test ensures that code generated by extension macros gets emitted into the correct LLVM module
// rdar://128870792

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %host-build-swift -swift-version 5 -emit-library -o %t/%target-library-name(MacroDefinition) -parse-as-library -module-name=MacroDefinition %t/macro.swift -g -no-toolchain-stdlib-rpath

// RUN: %target-swift-frontend -num-threads 1 -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -enable-library-evolution %t/b.swift %t/a.swift -emit-ir -o %t/b.ll -o %t/a.ll

// RUN: %FileCheck -check-prefix=CHECK-A %s < %t/a.ll

// RUN: %FileCheck -check-prefix=CHECK-B %s < %t/b.ll

//--- macro.swift

import SwiftSyntax
import SwiftSyntaxBuilder
@_spi(ExperimentalLanguageFeature) import SwiftSyntaxMacros

public struct SomeExtensionMacro: ExtensionMacro {
  public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
    let decl: DeclSyntax =
    """
    extension \(type.trimmed) {
      struct Storage {
        let x: Int
      }

      func alsoUseStorage(_ x: Storage?) {
        print(type(of: x))
      }
    }
    """
    guard let extensionDecl = decl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    return [extensionDecl]
  }
}

//--- a.swift

@attached(
  extension,
  names: named(Storage), named(alsoUseStorage)
)
macro someExtension() = #externalMacro(module: "MacroDefinition", type: "SomeExtensionMacro")

// CHECK-A: @"$s1b1SV7StorageVMn" = {{.*}}constant
@someExtension
struct S {}

//--- b.swift

// This file needs no content, it just needs to exist

// CHECK-B-NOT: @"$s1b1SV7StorageVMn"
