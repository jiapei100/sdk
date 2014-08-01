// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This code was auto-generated, is not intended to be edited, and is subject to
// significant change. Please see the README file for more information.

library services.src.correction.util;

import 'package:analysis_services/src/correction/source_range.dart';
import 'package:analysis_services/src/correction/strings.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';


String getDefaultValueCode(DartType type) {
  if (type != null) {
    String typeName = type.displayName;
    if (typeName == "bool") {
      return "false";
    }
    if (typeName == "int") {
      return "0";
    }
    if (typeName == "double") {
      return "0.0";
    }
    if (typeName == "String") {
      return "''";
    }
  }
  // no better guess
  return "null";
}


/**
 * @return the [ExecutableElement] of the enclosing executable [AstNode].
 */
ExecutableElement getEnclosingExecutableElement(AstNode node) {
  while (node != null) {
    if (node is FunctionDeclaration) {
      return node.element;
    }
    if (node is ConstructorDeclaration) {
      return node.element;
    }
    if (node is MethodDeclaration) {
      return node.element;
    }
    node = node.parent;
  }
  return null;
}


/**
 * Returns a namespace of the given [ExportElement].
 */
Map<String, Element> getExportNamespaceForDirective(ExportElement exp) {
  Namespace namespace =
      new NamespaceBuilder().createExportNamespaceForDirective(exp);
  return namespace.definedNames;
}


/**
 * Returns a export namespace of the given [LibraryElement].
 */
Map<String, Element> getExportNamespaceForLibrary(LibraryElement library) {
  Namespace namespace =
      new NamespaceBuilder().createExportNamespaceForLibrary(library);
  return namespace.definedNames;
}


/**
 * Returns an [Element] exported from the given [LibraryElement].
 */
Element getExportedElement(LibraryElement library, String name) {
  if (library == null) {
    return null;
  }
  return getExportNamespaceForLibrary(library)[name];
}

/**
 * Returns [getExpressionPrecedence] for the parent of [node],
 * or `0` if the parent node is [ParenthesizedExpression].
 *
 * The reason is that `(expr)` is always executed after `expr`.
 */
int getExpressionParentPrecedence(AstNode node) {
  AstNode parent = node.parent;
  if (parent is ParenthesizedExpression) {
    return 0;
  }
  return getExpressionPrecedence(parent);
}


/**
 * Returns the precedence of [node] it is an [Expression], negative otherwise.
 */
int getExpressionPrecedence(AstNode node) {
  if (node is Expression) {
    return node.precedence;
  }
  return -1000;
}

/**
 * Returns the namespace of the given [ImportElement].
 */
Map<String, Element> getImportNamespace(ImportElement imp) {
  NamespaceBuilder builder = new NamespaceBuilder();
  Namespace namespace = builder.createImportNamespaceForDirective(imp);
  return namespace.definedNames;
}

/**
 * If given [AstNode] is name of qualified property extraction, returns target from which
 * this property is extracted. Otherwise `null`.
 */
Expression getQualifiedPropertyTarget(AstNode node) {
  AstNode parent = node.parent;
  if (parent is PrefixedIdentifier) {
    PrefixedIdentifier prefixed = parent;
    if (identical(prefixed.identifier, node)) {
      return parent.prefix;
    }
  }
  if (parent is PropertyAccess) {
    PropertyAccess access = parent;
    if (identical(access.propertyName, node)) {
      return access.realTarget;
    }
  }
  return null;
}

/**
 * Returns the [String] content of the given [Source].
 */
String getSourceContent(AnalysisContext context, Source source) {
  return context.getContents(source).data;
}

class CorrectionUtils {
  final CompilationUnit unit;

  LibraryElement _library;
  String _buffer;
  String _endOfLine;

  CorrectionUtils(this.unit) {
    CompilationUnitElement unitElement = unit.element;
    this._library = unitElement.library;
    this._buffer = unitElement.context.getContents(unitElement.source).data;
  }

  /**
   * Returns the EOL to use for this [CompilationUnit].
   */
  String get endOfLine {
    if (_endOfLine == null) {
      if (_buffer.contains("\r\n")) {
        _endOfLine = "\r\n";
      } else {
        _endOfLine = "\n";
      }
    }
    return _endOfLine;
  }

  /**
   * Returns the actual type source of the given [Expression], may be `null`
   * if can not be resolved, should be treated as the `dynamic` type.
   */
  String getExpressionTypeSource(Expression expression) {
    if (expression == null) {
      return null;
    }
    DartType type = expression.bestType;
    if (type.isDynamic) {
      return null;
    }
    return getTypeSource(type);
  }

  /**
   * Returns the indentation with the given level.
   */
  String getIndent(int level) => repeat('  ', level);

  /**
   * Returns a [InsertDesc] describing where to insert a new library-related
   * directive.
   */
  CorrectionUtils_InsertDesc getInsertDescImport() {
    // analyze directives
    Directive prevDirective = null;
    for (Directive directive in unit.directives) {
      if (directive is LibraryDirective ||
          directive is ImportDirective ||
          directive is ExportDirective) {
        prevDirective = directive;
      }
    }
    // insert after last library-related directive
    if (prevDirective != null) {
      CorrectionUtils_InsertDesc result = new CorrectionUtils_InsertDesc();
      result.offset = prevDirective.end;
      String eol = endOfLine;
      if (prevDirective is LibraryDirective) {
        result.prefix = "${eol}${eol}";
      } else {
        result.prefix = eol;
      }
      return result;
    }
    // no directives, use "top" location
    return getInsertDescTop();
  }

  /**
   * Returns a [InsertDesc] describing where to insert a new 'part' directive.
   */
  CorrectionUtils_InsertDesc getInsertDescPart() {
    // analyze directives
    Directive prevDirective = null;
    for (Directive directive in unit.directives) {
      prevDirective = directive;
    }
    // insert after last directive
    if (prevDirective != null) {
      CorrectionUtils_InsertDesc result = new CorrectionUtils_InsertDesc();
      result.offset = prevDirective.end;
      String eol = endOfLine;
      if (prevDirective is PartDirective) {
        result.prefix = eol;
      } else {
        result.prefix = "${eol}${eol}";
      }
      return result;
    }
    // no directives, use "top" location
    return getInsertDescTop();
  }

  /**
   * Returns a [InsertDesc] describing where to insert a new directive or a
   * top-level declaration at the top of the file.
   */
  CorrectionUtils_InsertDesc getInsertDescTop() {
    // skip leading line comments
    int offset = 0;
    bool insertEmptyLineBefore = false;
    bool insertEmptyLineAfter = false;
    String source = _buffer;
    // skip hash-bang
    if (offset < source.length - 2) {
      String linePrefix = getText2(offset, 2);
      if (linePrefix == "#!") {
        insertEmptyLineBefore = true;
        offset = getLineNext(offset);
        // skip empty lines to first line comment
        int emptyOffset = offset;
        while (emptyOffset < source.length - 2) {
          int nextLineOffset = getLineNext(emptyOffset);
          String line = source.substring(emptyOffset, nextLineOffset);
          if (line.trim().isEmpty) {
            emptyOffset = nextLineOffset;
            continue;
          } else if (line.startsWith("//")) {
            offset = emptyOffset;
            break;
          } else {
            break;
          }
        }
      }
    }
    // skip line comments
    while (offset < source.length - 2) {
      String linePrefix = getText2(offset, 2);
      if (linePrefix == "//") {
        insertEmptyLineBefore = true;
        offset = getLineNext(offset);
      } else {
        break;
      }
    }
    // determine if empty line is required after
    int nextLineOffset = getLineNext(offset);
    String insertLine = source.substring(offset, nextLineOffset);
    if (!insertLine.trim().isEmpty) {
      insertEmptyLineAfter = true;
    }
    // fill InsertDesc
    CorrectionUtils_InsertDesc desc = new CorrectionUtils_InsertDesc();
    desc.offset = offset;
    if (insertEmptyLineBefore) {
      desc.prefix = endOfLine;
    }
    if (insertEmptyLineAfter) {
      desc.suffix = endOfLine;
    }
    return desc;
  }

  /**
   * Skips whitespace characters and single EOL on the right from [index].
   *
   * If [index] the end of a statement or method, then in the most cases it is
   * a start of the next line.
   */
  int getLineContentEnd(int index) {
    int length = _buffer.length;
    // skip whitespace characters
    while (index < length) {
      int c = _buffer.codeUnitAt(index);
      if (!isWhitespace(c) || c == 0x0D || c == 0x0A) {
        break;
      }
      index++;
    }
    // skip single \r
    if (index < length && _buffer.codeUnitAt(index) == 0x0D) {
      index++;
    }
    // skip single \n
    if (index < length && _buffer.codeUnitAt(index) == 0x0A) {
      index++;
    }
    // done
    return index;
  }

  /**
   * Skips spaces and tabs on the left from [index].
   *
   * If [index] is the start or a statement, then in the most cases it is a
   * start on its line.
   */
  int getLineContentStart(int index) {
    while (index > 0) {
      int c = _buffer.codeUnitAt(index - 1);
      if (!isSpace(c)) {
        break;
      }
      index--;
    }
    return index;
  }

  /**
   * Returns a start index of the next line after the line which contains the
   * given index.
   */
  int getLineNext(int index) {
    int length = _buffer.length;
    // skip to the end of the line
    while (index < length) {
      int c = _buffer.codeUnitAt(index);
      if (c == 0xD || c == 0xA) {
        break;
      }
      index++;
    }
    // skip single \r
    if (index < length && _buffer.codeUnitAt(index) == 0xD) {
      index++;
    }
    // skip single \n
    if (index < length && _buffer.codeUnitAt(index) == 0xA) {
      index++;
    }
    // done
    return index;
  }

  /**
   * Returns the whitespace prefix of the line which contains given offset.
   */
  String getLinePrefix(int index) {
    int lineStart = getLineThis(index);
    int length = _buffer.length;
    int lineNonWhitespace = lineStart;
    while (lineNonWhitespace < length) {
      int c = _buffer.codeUnitAt(lineNonWhitespace);
      if (c == 0xD || c == 0xA) {
        break;
      }
      if (!isWhitespace(c)) {
        break;
      }
      lineNonWhitespace++;
    }
    return getText2(lineStart, lineNonWhitespace - lineStart);
  }

  /**
   * Returns the start index of the line which contains given index.
   */
  int getLineThis(int index) {
    while (index > 0) {
      int c = _buffer.codeUnitAt(index - 1);
      if (c == 0xD || c == 0xA) {
        break;
      }
      index--;
    }
    return index;
  }

  /**
   * Returns a [SourceRange] that covers [range] and extends (if possible) to
   * cover whole lines.
   */
  SourceRange getLinesRange(SourceRange range) {
    // start
    int startOffset = range.offset;
    int startLineOffset = getLineContentStart(startOffset);
    // end
    int endOffset = range.end;
    int afterEndLineOffset = getLineContentEnd(endOffset);
    // range
    return rangeStartEnd(startLineOffset, afterEndLineOffset);
  }

  /**
   * Returns the line prefix consisting of spaces and tabs on the left from the given
   *         [AstNode].
   */
  String getNodePrefix(AstNode node) {
    int offset = node.offset;
    // function literal is special, it uses offset of enclosing line
    if (node is FunctionExpression) {
      return getLinePrefix(offset);
    }
    // use just prefix directly before node
    return getPrefix(offset);
  }

  /**
   * @return the source for the parameter with the given type and name.
   */
  String getParameterSource(DartType type, String name) {
    // no type
    if (type == null || type.isDynamic) {
      return name;
    }
    // function type
    if (type is FunctionType) {
      FunctionType functionType = type;
      StringBuffer sb = new StringBuffer();
      // return type
      DartType returnType = functionType.returnType;
      if (returnType != null && !returnType.isDynamic) {
        sb.write(getTypeSource(returnType));
        sb.write(' ');
      }
      // parameter name
      sb.write(name);
      // parameters
      sb.write('(');
      List<ParameterElement> fParameters = functionType.parameters;
      for (int i = 0; i < fParameters.length; i++) {
        ParameterElement fParameter = fParameters[i];
        if (i != 0) {
          sb.write(", ");
        }
        sb.write(getParameterSource(fParameter.type, fParameter.name));
      }
      sb.write(')');
      // done
      return sb.toString();
    }
    // simple type
    return "${getTypeSource(type)} ${name}";
  }

  /**
   * Returns the line prefix consisting of spaces and tabs on the left from the
   * given offset.
   */
  String getPrefix(int endIndex) {
    int startIndex = getLineContentStart(endIndex);
    return _buffer.substring(startIndex, endIndex);
  }

  /**
   * Returns the text of the given [AstNode] in the unit.
   */
  String getText(AstNode node) {
    // TODO(scheglov) rename
    return getText2(node.offset, node.length);
  }

  /**
   * Returns the text of the given range in the unit.
   */
  String getText2(int offset, int length) {
    // TODO(scheglov) rename
    return _buffer.substring(offset, offset + length);
  }

  /**
   * Returns the text of the given range in the unit.
   */
  String getText3(SourceRange range) {
    // TODO(scheglov) rename
    return getText2(range.offset, range.length);
  }

  /**
   * Returns the source to reference [type] in this [CompilationUnit].
   */
  String getTypeSource(DartType type) {
    StringBuffer sb = new StringBuffer();
    // just some Function, maybe find Function Type Alias later
    if (type is FunctionType) {
      return "Function";
    }
    // prepare element
    Element element = type.element;
    if (element == null) {
      String source = type.toString();
      source = source.replaceAll('<dynamic>', '');
      source = source.replaceAll('<dynamic, dynamic>', '');
      return source;
    }
    // append prefix
    {
      ImportElement imp = _getImportElement(element);
      if (imp != null && imp.prefix != null) {
        sb.write(imp.prefix.displayName);
        sb.write(".");
      }
    }
    // append simple name
    String name = element.displayName;
    sb.write(name);
    // may be type arguments
    if (type is InterfaceType) {
      InterfaceType interfaceType = type;
      List<DartType> arguments = interfaceType.typeArguments;
      // check if has arguments
      bool hasArguments = false;
      for (DartType argument in arguments) {
        if (!argument.isDynamic) {
          hasArguments = true;
          break;
        }
      }
      // append type arguments
      if (hasArguments) {
        sb.write("<");
        for (int i = 0; i < arguments.length; i++) {
          DartType argument = arguments[i];
          if (i != 0) {
            sb.write(", ");
          }
          sb.write(getTypeSource(argument));
        }
        sb.write(">");
      }
    }
    // done
    return sb.toString();
  }

  /**
   * @return the [ImportElement] used to import given [Element] into [library].
   *         May be `null` if was not imported, i.e. declared in the same library.
   */
  ImportElement _getImportElement(Element element) {
    for (ImportElement imp in _library.imports) {
      Map<String, Element> definedNames = getImportNamespace(imp);
      if (definedNames.containsValue(element)) {
        return imp;
      }
    }
    return null;
  }
}


/**
 * Describes where to insert new directive or top-level declaration.
 */
class CorrectionUtils_InsertDesc {
  int offset = 0;
  String prefix = "";
  String suffix = "";
}
