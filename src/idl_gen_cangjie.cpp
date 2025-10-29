// This source file is part of the Cangjie project.
//
// Copyright (c) 2025 Huawei Technologies Co., Ltd. and the Cangjie project authors.
// Licensed under Apache-2.0 with Runtime Library Exceptions.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information

#include "idl_gen_cangjie.h"

#include <cctype>
#include <iostream>
#include <string>
#include <unordered_set>

#include "flatbuffers/code_generators.h"
#include "flatbuffers/flatbuffers.h"
#include "flatbuffers/idl.h"
#include "flatbuffers/util.h"

namespace flatbuffers {

namespace cangjie {

inline char CharToLower(char c) { return static_cast<char>(::tolower(static_cast<unsigned char>(c))); }

// Convert an underscore_based_identifier into camelCase.
// Also uppercases the first character if first is true.
static std::string MakeCamel(const std::string &in, bool first) {
  std::string s;
  for (size_t i = 0; i < in.length(); i++) {
    if (!i && first)
      s += CharToUpper(in[0]);
    else if (in[i] == '_' && i + 1 < in.length())
      s += CharToUpper(in[++i]);
    else
      s += in[i];
  }
  return s;
}

// Convert an underscore_based_identifier into screaming snake case.
static std::string MakeScreamingCamel(const std::string& in)
{
    std::string s;
    for (size_t i = 0; i < in.length(); i++) {
        if (in[i] != '_') {
            s += static_cast<char>(toupper(in[i]));
        } else {
            s += in[i];
        }
    }
    return s;
}

/*
 scalar type: int8,  int16,  int32,  int64  -> GetInt8Slot
              uint8, uint16, uint32, uint64 -> GetUInt8Slot
 */
inline std::string GenGetScalarType(const std::string& input) { return "get" + input + "Slot"; }

inline std::string GenIndirect(const std::string& reading) { return "{{ACCESS}}.getIndirect(" + reading + ")"; }

inline std::string GenArrayMainBody(bool is_content_optional, const std::string& optional)
{
    std::string return_type = is_content_optional ? "Array<Option<{{VALUETYPE}}>>" : "Array<{{VALUETYPE}}>";
    return "{{ACCESS_TYPE}}func {{VALUENAME}}() : " + return_type + optional + " {";
}

class CjGenerator : public BaseGenerator {
private:
    CodeWriter code_;
    std::unordered_set<std::string> keywords_;
    int namespace_depth;

public:
    CjGenerator(const Parser& parser, const std::string& path, const std::string& file_name)
        : BaseGenerator(parser, path, file_name, "", "_", "cj")
    {
        namespace_depth = 0;
        code_.SetPadding("    ");
        code_.SetValue("NAMESPACE", "{}");
        // keywords of Cangjie
        static const char *const keywords[] = {
          "as",
          "abstract",
          "break",
          "Bool",
          "case",
          "catch",
          "class",
          "const",
          "continue",
          "Rune",
          "do",
          "else",
          "enum",
          "extend",
          "for",
          "func",
          "false",
          "finally",
          "foreign",
          "Float16",
          "Float32",
          "Float64",
          "if",
          "in",
          "is",
          "init",
          "import",
          "interface",
          "Int8",
          "Int16",
          "Int32",
          "Int64",
          "IntNative",
          "let",
          "mut",
          "main",
          "macro",
          "match",
          "Nothing",
          "open",
          "operator",
          "override",
          "prop",
          "public",
          "package",
          "private",
          "protected",
          "quote",
          "redef",
          "return",
          "spawn",
          "super",
          "static",
          "struct",
          "synchronized",
          "try",
          "this",
          "true",
          "type",
          "throw",
          "This",
          "unsafe",
          "Unit",
          "UInt8",
          "UInt16",
          "UInt32",
          "UInt64",
          "UIntNative",
          "var",
          "VArray",
          "where",
          "while",
          nullptr,
        };
        for (auto kw = keywords; *kw; kw++) {
            keywords_.insert(*kw);
        }
    }

    ~CjGenerator() {}

    bool generate()
    {
        code_.Clear();
        code_.SetValue("ACCESS", "this.table"); // Defined in super class
        code_.SetValue("TABLEOFFSET", "VTOFFSET");
        code_ += "// " + std::string(FlatBuffersGeneratedWarning());
        code_ += "// cangjielint:disable all\n";
        code_ += "// cangjieformat:disable all\n";
        code_ += "package std.ast";
        code_ += "";

        // Generate code for all the enum declarations.
        for (auto it = parser_.enums_.vec.begin(); it != parser_.enums_.vec.end(); ++it) {
            const auto& enum_def = **it;
            if (!enum_def.generated) {
                GenEnum(enum_def);
            }
        }

        // Generate code for all the struct declarations
        for (auto it = parser_.structs_.vec.begin(); it != parser_.structs_.vec.end(); ++it) {
            const auto& struct_def = **it;
            if (struct_def.fixed && !struct_def.generated) {
                GenStructReader(struct_def);
            }
        }

        // Generate code for all the table declarations
        for (auto it = parser_.structs_.vec.begin(); it != parser_.structs_.vec.end(); ++it) {
            const auto& struct_def = **it;
            if (!struct_def.fixed && !struct_def.generated) {
                GenTable(struct_def);
            }
        }

        const auto filename = GeneratedFileName(path_, file_name_, parser_.opts);
        const auto final_code = code_.ToString();
        return SaveFile(filename.c_str(), final_code, false);
    }

    std::string MakeTypeCamel(const std::string& type_name, bool first)
    {
        std::string s;
        std::string strOfUnit = "UInt";
        size_t i = 0;
        if (type_name.compare(0, 4, strOfUnit) == 0) {
            s += "UInt";
            i += strOfUnit.size();
        }
        for (; i < type_name.length(); i++) {
            if (!i && first) {
                s += static_cast<char>(toupper(type_name[0]));
            } else if (type_name[i] == '_' && i + 1 < type_name.length()) {
                s += static_cast<char>(toupper(type_name[++i]));
            } else {
                s += type_name[i];
            }
        }
        return s;
    }

    void GenObjectHeader(const StructDef& struct_def)
    {
        GenComment(struct_def.doc_comment);
        code_.SetValue("SHORT_STRUCTNAME", Name(struct_def));
        code_.SetValue("STRUCTNAME", NameWrappedInNameSpace(struct_def));
        code_.SetValue("PROTOCOL", struct_def.fixed ? "" : "<: FlatBufferObject ");
        code_.SetValue("OBJECTTYPE", struct_def.fixed ? "struct" : "class");
        code_.SetValue("VISIBILITYTYPE", struct_def.fixed ? "" : "public");
        code_ += "{{VISIBILITYTYPE}} {{OBJECTTYPE}} {{STRUCTNAME}} {{PROTOCOL}}{";
        Indent();
        // Generate Table constructor
        if (struct_def.fixed) {
            // declare members
            code_ += "static let BYTE_ALIGNMENT: UInt32 = " + std::to_string(struct_def.minalign);
            code_ += "";
            for (auto element : struct_def.fields.vec) {
                const auto& field = *element;
                code_ += "let " + Name(field) + ": " + GenType(field.value.type);
            }
            code_ += "";
            // empty constructor
            code_ += "init() {";
            Indent();
            for (auto element : struct_def.fields.vec) {
                const auto& field = *element;
                code_ += Name(field) + " = 0"; // FIXME: all set to be zero?
            }
            Outdent();
            code_ += "}";
            code_ += "";
            // constructor
            code_ += "init(buf: Array<UInt8>, pos: UInt32) {";
            Indent();
            code_ +=
                "boundsCheck(buf, Int64(pos + " + std::to_string(struct_def.fields.vec.size()) + " * BYTE_ALIGNMENT))";
            int cnt = 0;
            const std::map<std::string, size_t> TypeSize = {
              {"UInt8",  1},
              {"UInt16", 2},
              {"UInt32", 4},
              {"UInt64", 8},
              {"Int8",   1},
              {"Int16",  2},
              {"Int32",  4},
              {"Int64",  8},
              {"Bool",   1}
            };

            for (auto element : struct_def.fields.vec) {
                std::string get_type_method = MakeTypeCamel(GenType(element->value.type), true);
                const auto& field = *element;
                FLATBUFFERS_ASSERT(TypeSize.count(get_type_method) != 0);
                size_t field_size = TypeSize.at(get_type_method);
                if (cnt == 0) {
                    std::string type_buf = "(buf[Int64(pos)..Int64(pos + " + std::to_string(field_size) + ")])";
                    code_ += Name(field) + " = get" + get_type_method + type_buf;
                } else {
                    std::string start = "pos + " + std::to_string(cnt) + " * BYTE_ALIGNMENT";
                    std::string end = start + " + " + std::to_string(field_size);

                    std::string type_buf = "(buf[Int64(" + start + ")..Int64(" + end + ")])";
                    code_ += Name(field) + " = get" + get_type_method + type_buf;
                }
                cnt++;
            }
            Outdent();
            code_ += "}";
        } else {
            code_ += "init(buf: Array<UInt8>, offset: UInt32) {";
            Indent();
            code_ += "super(buf, offset)";
            Outdent();
            code_ += "}\n";
        }
    }

    // Generates the reader for Cangjie
    void GenTable(const StructDef& struct_def)
    {
        code_.SetValue("ACCESS_TYPE", "");

        GenObjectHeader(struct_def);
        GenTableAccessors(struct_def);
        GenTableReader(struct_def);

        Outdent();
        code_ += "}\n";
    }

    void GenTableAccessors(const StructDef& struct_def)
    {
        // Generate field id constants.
        if (struct_def.fields.vec.size() > 0) {
            for (auto it = struct_def.fields.vec.begin(); it != struct_def.fields.vec.end(); ++it) {
                const auto& field = **it;
                if (field.deprecated) {
                    continue;
                }
                code_.SetValue("OFFSET_NAME", MakeScreamingCamel(field.name));
                code_.SetValue("OFFSET_VALUE", NumToString(field.value.offset));
                code_ += "let {{OFFSET_NAME}} : UInt16 = {{OFFSET_VALUE}}";
            }
            code_ += "";
        }
    }

    void GenTableReader(const StructDef& struct_def)
    {
        for (auto it = struct_def.fields.vec.begin(); it != struct_def.fields.vec.end(); ++it) {
            auto& field = **it;
            if (field.deprecated) {
                continue;
            }
            GenTableReaderFields(field);
        }
    }

    inline std::string GenOption(const EnumDef& enum_def) { return "Option<" + NameWrappedInNameSpace(enum_def) + ">"; }

    std::string GetUnionElement(const EnumVal& ev, bool wrap, bool actual_type, bool native_type = false)
    {
        if (ev.union_type.base_type == BASE_TYPE_STRUCT) {
            auto name = actual_type ? ev.union_type.struct_def->name : Name(ev);
            return wrap ? WrapInNameSpace(ev.union_type.struct_def->defined_namespace, name) : name;
        } else if (ev.union_type.base_type == BASE_TYPE_STRING) {
            return actual_type ? (native_type ? "std::string" : "flatbuffers::String") : Name(ev);
        } else {
            FLATBUFFERS_ASSERT(false);
            return Name(ev);
        }
    }

    void GenTableReaderFields(const FieldDef& field)
    {
        auto offset = NumToString(field.value.offset);
        auto name = MakeScreamingCamel(field.name);
        auto func_name = "Get" + EscapeKeyword(MakeCamel(field.name, true));
        auto type = GenType(field.value.type);
        code_.SetValue("VALUENAME", func_name);
        code_.SetValue("VALUETYPE", type);
        code_.SetValue("OFFSET", name);
        code_.SetValue("CONSTANT", field.value.constant); // field value
        bool opt_scalar = IsScalar(field.value.type.base_type);
        std::string def_Val = opt_scalar ? "{{VALUETYPE}}(0)" : "{{CONSTANT}}";
        bool optional = false;
        GenComment(field.doc_comment);
        if (IsScalar(field.value.type.base_type) && !IsEnum(field.value.type) && !IsBool(field.value.type.base_type)) {
            code_ += GenReaderMainBody(optional);
            Indent();
            // UInt8 -> GetUInt8Slot()
            code_ += "return {{ACCESS}}." + GenGetScalarType(type) + "({{OFFSET}}, {{CONSTANT}})";
            Outdent();
            code_ += "}";
            return;
        }

        if (IsBool(field.value.type.base_type)) {
            std::string default_value = "0" == field.value.constant ? "false" : "true";
            code_.SetValue("CONSTANT", default_value);
            code_ += GenReaderMainBody(optional);
            Indent();
            code_ += GenOffset();

            code_ += "return if (o == 0) {";
            Indent();
            code_ += "false";
            Outdent();
            code_ += "} else {";
            Indent();
            code_ += "{{ACCESS}}.getBool(UInt32(o) + {{ACCESS}}.pos)";
            Outdent();
            code_ += "}";
            Outdent();
            code_ += "}";
            return;
        }

        if (IsEnum(field.value.type)) {
            auto default_value = GenEnumDefaultValue(field);
            code_.SetValue("BASEVALUE", GenTypeBasic(field.value.type, false));
            code_ += GenReaderMainBody(optional);
            Indent();
            code_ += GenOffsetU32();
            code_ += "let off : UInt32 = o + {{ACCESS}}.pos";

            code_ += "return if (o == 0) {";
            Indent();
            code_ += default_value;
            Outdent();
            code_ += "} else {";
            Indent();
            code_ += "EnumValues{{VALUETYPE}}(this.table.get{{BASEVALUE}}(off))";
            Outdent();
            code_ += "}";
            Outdent();
            code_ += "}";
            return;
        }

        bool is_required = false;
        std::string required_reader = "return ";
        if (IsStruct(field.value.type) && field.value.type.struct_def->fixed) {
            code_.SetValue("VALUETYPE", GenType(field.value.type));
            code_.SetValue("CONSTANT", GenType(field.value.type) + "()");
            code_ += GenReaderMainBody(is_required);
            Indent();
            code_ += GenOffsetU32();
            code_ += required_reader + GenConstructor("o + {{ACCESS}}.pos");
            Outdent();
            code_ += "}";
            return;
        }
        std::string option_some;
        std::string option_none;
        switch (field.value.type.base_type) {
            case BASE_TYPE_STRUCT:
                // fix table in table
                code_.SetValue("VALUETYPE", GenType(field.value.type));
                code_.SetValue("CONSTANT", "Unit");
                code_ += GenReaderMainBody(true);
                Indent();
                code_ += GenOffset();
                option_some = "Some<{{VALUETYPE}}>(" + GenConstructor(("UInt32(o) + {{ACCESS}}.pos")) + ")";
                option_none = "None<{{VALUETYPE}}>";
                code_ += "return if (o == 0) {";
                Indent();
                code_ += option_none;
                Outdent();
                code_ += "} else {";
                Indent();
                code_ += option_some;
                Outdent();
                code_ += "}";
                Outdent();
                code_ += "}\n";
                break;

            case BASE_TYPE_STRING:
                code_.SetValue("VALUETYPE", GenType(field.value.type));
                code_.SetValue("CONSTANT", "\"\"");
                code_ += GenReaderMainBody(is_required);
                Indent();
                code_ += GenOffsetU32() + " + {{ACCESS}}.pos";
                code_ += "return if (o == 0) {";
                Indent();
                code_ += "{{CONSTANT}}";
                Outdent();
                code_ += "} else {";
                Indent();
                code_ += "{{ACCESS}}.getString(o)";
                Outdent();
                code_ += "}";
                Outdent();
                code_ += "}";
                break;

            case BASE_TYPE_VECTOR:
                GenTableReaderVectorFields(field);
                break;
            case BASE_TYPE_UNION:
                for (auto& u_it : field.value.type.enum_def->Vals()) {
                    auto& ev = *u_it;
                    if (ev.union_type.base_type == BASE_TYPE_NONE) {
                        continue;
                    }
                    // Generate name from Type
                    auto get_type_method =
                        "Get" + MakeCamel(field.name, true) + "As" + GetUnionElement(ev, false, true);
                    auto enum_name = GetUnionElement(ev, true, true);
                    std::string option_name = "Option<" + enum_name + ">";
                    code_ += "{{ACCESS_TYPE}}func " + get_type_method + "() : " + option_name + " {";
                    Indent();
                    code_ += GenOffset();
                    code_ += "let off : UInt32 = UInt32(o) + {{ACCESS}}.pos";
                    code_ += "return match (this.Get" + MakeCamel(field.name, true) + "Type()) {";
                    Indent();
                    auto struct_constructor = enum_name + "(this.table.bytes, " + "off)";
                    option_some = "Some<" + enum_name + ">(" + struct_constructor + ")";
                    option_none = "None<" + enum_name + ">";
                    code_ += "case " + field.value.type.enum_def->name + "_" + ev.name + " => " + option_some;
                    code_ += "case _ => " + option_none;
                    Outdent();
                    code_ += "}";
                    Outdent();
                    code_ += "}\n";
                }
                break;
            default:
                FLATBUFFERS_ASSERT(0);
        }
    }

    void GenTableReaderVectorFields(const FieldDef& field)
    {
        auto vectortype = field.value.type.VectorType();
        code_.SetValue("SIZE", NumToString(InlineSize(vectortype)));
        code_.SetValue("CONSTANT", IsScalar(vectortype.base_type) == true ? field.value.constant : "unit");
        auto nullable = "";
        auto is_vector_of_structs = vectortype.base_type == BASE_TYPE_STRUCT && field.value.type.struct_def->fixed;
        auto is_vector_of_integers = IsInteger(vectortype.base_type) && !IsEnum(vectortype);
        if (vectortype.base_type != BASE_TYPE_UNION) {
            auto is_content_optional = !is_vector_of_integers && !is_vector_of_structs;
            code_ += GenArrayMainBody(is_content_optional, nullable);
            Indent();
        } else {
            code_ += "{{ACCESS_TYPE}}func {{VALUENAME}}(index: "
                     "Int32) : FlatBufferObject {";
            Indent();
            code_ += GenOffset();
        }


        if (is_vector_of_integers) {
            code_ += GenOffsetU32();
            code_ += "let vectorLoc: UInt32 = " + GenIndirect("o + {{ACCESS}}.pos");
            code_ += "let vectorLength: UInt32 = {{ACCESS}}.getUInt32(vectorLoc)";
            code_ += "let vectorStart = vectorLoc + 4";

            code_ += "return Array<{{VALUETYPE}}>(Int64(vectorLength)) { i =>";
            Indent();
            code_ += "let vecElement = vectorStart + UInt32(i) * {{SIZE}}";
            auto integer_type =  (IsUnsigned(vectortype.base_type) ? "UInt" : "Int") + std::to_string(SizeOf(vectortype.base_type) * 8);
            auto element_type = IsBool(vectortype.base_type) ? "Bool" : integer_type;
            code_ += "{{ACCESS}}.get" + element_type + "(vecElement)";
            Outdent();

            code_ += "}";
            Outdent();
            code_ += "}";
            return;
        }

        if (is_vector_of_structs) {
            code_ += GenOffsetU32();
            code_ += "let vectorLoc: UInt32 = " + GenIndirect("o + {{ACCESS}}.pos");
            code_ += "let vectorLength: UInt32 = {{ACCESS}}.getUInt32(vectorLoc)";
            code_ += "let vectorStart = vectorLoc + 4";

            code_ += "return Array<{{VALUETYPE}}>(Int64(vectorLength)) { i =>";
            Indent();
            code_ += "let vecElement = vectorStart + UInt32(i) * {{SIZE}}";
            code_ += GenConstructor("vecElement");
            Outdent();

            code_ += "}";
            Outdent();
            code_ += "}";
            return;
        }

        if (vectortype.base_type == BASE_TYPE_STRING) {
            code_ += "let ELEMENT_STRIDE: UInt32 = 4";
            code_.SetValue("fieldNameCaps", MakeScreamingCamel(field.name));
            code_ += "let LENGTH: Int64 = {{ACCESS}}.getVectorLenBySlot({{fieldNameCaps}})";
            code_ += "var arr: Array<Option<String>> = Array<Option<String>>(LENGTH, repeat: None<String>)";
            code_ += "let start: UInt32 = {{ACCESS}}.getVectorStartBySlot({{fieldNameCaps}})";
            code_ += "for (i in 0..LENGTH) {";
            Indent();
            code_ += "let p: UInt32 = start + UInt32(i) * ELEMENT_STRIDE";
            code_ += "arr[i] = if ({{ACCESS}}.getIndirect(p) == p) {";
            Indent();
            code_ += "None<String>";
            Outdent();
            code_ += "} else {";
            Indent();
            code_ += "Some<String>({{ACCESS}}.getString(p))";
            Outdent();
            code_ += "}";
            Outdent();
            code_ += "}";
            code_ += "return arr";
            Outdent();
            code_ += "}";
        }

        if (IsEnum(vectortype)) {
            code_ += "let ELEMENT_STRIDE: UInt32 = 4";
            code_.SetValue("fieldNameCaps", MakeScreamingCamel(field.name));
            code_.SetValue("BASEVALUE", GenTypeBasic(vectortype, false));
            code_ += "let LENGTH: Int64 = {{ACCESS}}.getVectorLenBySlot({{fieldNameCaps}})";
            code_ += "var arr = Array<?{{VALUETYPE}}>(LENGTH, repeat: None<{{VALUETYPE}}>)";
            code_ += "let start: UInt32 = {{ACCESS}}.getVectorStartBySlot({{fieldNameCaps}})";
            code_ += "for (i in 0..LENGTH) {";
            Indent();
            code_ += "let p: UInt32 = start + UInt32(i) * ELEMENT_STRIDE";
            code_ += "arr[i] = if ({{ACCESS}}.getIndirect(p) == p) {";
            Indent();
            code_ += "None<{{VALUETYPE}}>";
            Outdent();
            code_ += "} else {";
            Indent();
            code_ += "EnumValues{{VALUETYPE}}({{ACCESS}}.getUInt8(start + UInt32(i)))";
            Outdent();
            code_ += "}";
            Outdent();
            code_ += "}";
            code_ += "return arr";
            Outdent();
            code_ += "}";
            return;
        }
        if (vectortype.base_type == BASE_TYPE_UNION) {
            code_ += "let vectorLoc: UInt32 = " + GenIndirect("UInt32(o) + {{ACCESS}}.pos");
            code_ += "let vectorStart = vectorLoc + 4";
            std::string tmpStr = R"(if (o == 0) {
            FlatBufferObject(Array<UInt8>(), 0)
        } else {
            table.getUnion(vectorStart + UInt32(index) * 4)
        })";
            code_ += tmpStr;
            Outdent();
            code_ += "}";
            code_ += "func Get" + MakeCamel(field.name, true) + "Size(): Int64 {";
            Indent();
            code_ += "table.getVectorLenBySlot(" + MakeScreamingCamel(field.name) + "_TYPE)";
            Outdent();
            code_ += "}";
            code_ += "func Get" + MakeCamel(field.name, true) + "Type(index: UInt32): " +
                GenType(vectortype.enum_def->underlying_type) + " {";
            Indent();
            code_ += "let start = {{ACCESS}}.getVectorStartBySlot({{fieldNameCaps}})";
            code_ += "EnumValues" + GenType(vectortype.enum_def->underlying_type) +
                "({{ACCESS}}.getUInt8(start + index))";
            Outdent();
            code_ += "}\n";
            for (auto& u_it : vectortype.enum_def->Vals()) {
                auto& ev = *u_it;
                if (ev.union_type.base_type == BASE_TYPE_NONE) {
                    continue;
                }
                auto get_type_method =
                    "Get" + MakeCamel(field.name, true) + "As" + MakeCamel(ev.name, true);
                auto enum_name = GetUnionElement(ev, true, true);
                std::string option_name = "?" + enum_name;
                code_ += "{{ACCESS_TYPE}}func " + get_type_method + "(index: UInt32) : " + option_name + " {";
                Indent();
                code_ += GenOffset();
                code_ += "let vectorStart = " + GenIndirect("UInt32(o) + {{ACCESS}}.pos");
                code_ += "match (this.Get" + MakeCamel(field.name, true) + "Type(index)) {";
                Indent();
                auto ctor = enum_name + "({{ACCESS}}.bytes, vectorStart + (index + 1) * 4)";
                std::string option_some = "Some(" + ctor + ")";
                std::string option_none = "None<" + enum_name + ">";
                code_ += "case " + GenType(vectortype.enum_def->underlying_type) + "." + field.value.type.enum_def->name
                    + "_" + MakeScreamingCamel(ev.name) + " => " + option_some;
                code_ += "case _ => " + option_none;
                Outdent();
                code_ += "}";
                Outdent();
                code_ += "}\n";
            }
            return;
        }

        if (vectortype.base_type == BASE_TYPE_STRUCT && !field.value.type.struct_def->fixed) {
            // Vector of table
            code_ += "let ELEMENT_STRIDE: UInt32 = 4";
            code_.SetValue("fieldNameCaps", MakeScreamingCamel(field.name));
            code_ += "let LENGTH: Int64 = {{ACCESS}}.getVectorLenBySlot({{fieldNameCaps}})";
            code_ += "var arr: Array<Option<{{VALUETYPE}}>> = Array<Option<{{VALUETYPE}}>>(LENGTH,"
                " repeat: None<{{VALUETYPE}}>)";
            code_ += "let start: UInt32 = {{ACCESS}}.getVectorStartBySlot({{fieldNameCaps}})";
            code_ += "for (i in 0..LENGTH) {";
            Indent();
            code_ += "let p: UInt32 = start + UInt32(i) * ELEMENT_STRIDE";
            code_ += "arr[i] = if ({{ACCESS}}.getIndirect(p) == p) {";
            Indent();
            code_ += "None<{{VALUETYPE}}>";
            Outdent();
            code_ += "} else {";
            Indent();
            code_ += "Some<{{VALUETYPE}}>({{VALUETYPE}}({{ACCESS}}.bytes, p))";
            Outdent();
            code_ += "}";
            Outdent();
            code_ += "}";
            code_ += "return arr";
            Outdent();
            code_ += "}";
            auto& sd = *field.value.type.struct_def;
            auto& fields = sd.fields.vec;
            for (auto kit = fields.begin(); kit != fields.end(); ++kit) {
                auto& key_field = **kit;
                if (key_field.key) {
                    GenByKeyFunctions(key_field);
                    break;
                }
            }
        }
    }

    void GenByKeyFunctions(const FieldDef& key_field)
    {
        code_.SetValue("TYPE", GenType(key_field.value.type));
        code_ += "{{ACCESS_TYPE}}func {{VALUENAME}}By(key: {{TYPE}}) -> {{VALUETYPE}}? "
                 "{ \\";
        code_ += GenOffset() +
            "return o == 0 ? unit : {{VALUETYPE}}.lookupByKey(vector: "
            "{{ACCESS}}.vector(o), key: key, fbb: {{ACCESS}}.bb) }";
    }

    // Generates the reader for struct
    void GenStructReader(const StructDef& struct_def)
    {
        auto is_private_access = struct_def.attributes.Lookup("private");
        code_.SetValue("ACCESS_TYPE", is_private_access ? "internal " : "public ");

        GenObjectHeader(struct_def);
        for (auto it = struct_def.fields.vec.begin(); it != struct_def.fields.vec.end(); ++it) {
            auto& field = **it;
            if (field.deprecated) {
                continue;
            }
            auto offset = NumToString(field.value.offset);
            auto name = Name(field);
            auto type = GenType(field.value.type);
            code_.SetValue("VALUENAME", name);
            code_.SetValue("VALUETYPE", type);
            code_.SetValue("OFFSET", offset);
            GenComment(field.doc_comment);
            if (IsEnum(field.value.type)) {
                code_.SetValue("BASEVALUE", GenTypeBasic(field.value.type, false));
                code_ += GenReaderMainBody() + "return " + GenEnumConstructor("{{OFFSET}}") + "?? " +
                    GenEnumDefaultValue(field) + " }";
            } else if (IsStruct(field.value.type) && !IsScalar(field.value.type.base_type)) {
                code_.SetValue("VALUETYPE", GenType(field.value.type));
                code_ += GenReaderMainBody() + "return " + GenConstructor("{{ACCESS}}.postion + {{OFFSET}}");
                code_ += "}";
            }
        }
        Outdent();
        code_ += "}\n";
    }

    /* generate code with the following format, for Char doesn't support convert int to Enum
     * enum test {
     *   none |
     *   one |
     *   two
     * }
     * func EnumValuesType(e : UInt32) : Type {
     *   let values: Array<Type> = [
     *       Type.none
     *       Type.one
     *       Type.two
     *   ]
     *   return e < 3 ? values[Int64(e)] : .none
     * }
     */
    void GenEnumValues(const EnumDef* enum_def)
    {
        std::string enum_local_name = enum_def->name + "Type";
        code_.SetValue("ENUM_LOCAL_NAME", enum_local_name);
        code_ += "func EnumValues{{ENUM_NAME}}(e: {{BASE_TYPE}}) : {{ENUM_NAME}} {";
        Indent();
        code_ += "var values: Array<{{ENUM_NAME}}> = [";
        Indent();
        std::string noneName;
        int i = 1;
        if (!enum_def->Vals().empty()) {
            const auto& ev = **enum_def->Vals().begin();
            noneName = enum_def->name + "_" + MakeScreamingCamel(ev.name);
            code_ += "{{ENUM_NAME}}." + noneName + ",";
            for (auto it = enum_def->Vals().begin() + 1; it != enum_def->Vals().end(); ++it) {
                const auto& ev2 = **it;
                auto name = "." + enum_def->name + "_" + MakeScreamingCamel(ev2.name);
                code_.SetValue("ENUM_INT_VALUE", std::to_string(i));
                code_.SetValue("ENUM_KEY", name);
                if (it != enum_def->Vals().end() - 1) {
                    code_ += "{{ENUM_NAME}}{{ENUM_KEY}},";
                } else {
                    code_ += "{{ENUM_NAME}}{{ENUM_KEY}}";
                }
                ++i;
            }
        }
        Outdent();
        code_ += "]";
        code_ += "return if (e < " + std::to_string(i) + ")" + " { values[Int64(e)] } else { " + noneName + " }";
        Outdent();
        code_ += "}\n";
    }

    void GenEnum(const EnumDef& enum_def)
    {
        if (enum_def.generated) {
            return;
        }
        // Enum can only used in top level in Char
        code_.SetValue("ENUM_NAME", NameWrappedInNameSpace(enum_def));
        code_.SetValue("BASE_TYPE", GenTypeBasic(enum_def.underlying_type, false));

        GenComment(enum_def.doc_comment);

        code_ += "enum {{ENUM_NAME}} {";
        Indent();
        for (auto it = enum_def.Vals().begin(); it != enum_def.Vals().end(); ++it) {
            const auto& ev = **it;
            auto name = enum_def.name + "_" + MakeScreamingCamel(ev.name);
            code_.SetValue("KEY", name);
            code_.SetValue("TYPE", GenTypeBasic(ev.union_type, true));
            GenComment(ev.doc_comment);
            if (it != enum_def.Vals().end() - 1) {
                code_ += "{{KEY}} |";
            } else {
                code_ += "{{KEY}}";
            }
        }
        Outdent();
        code_ += "}\n";
        GenEnumValues(&enum_def);
    }

    void GenComment(const std::vector<std::string>& dc)
    {
        if (dc.begin() == dc.end()) {
            // Don't output empty comment blocks with 0 lines of comment content.
            return;
        }
        for (auto it = dc.begin(); it != dc.end(); ++it) {
            code_ += "/// " + *it;
        }
    }

    std::string GenOffset() { return "let o : UInt16 = {{ACCESS}}.offset({{OFFSET}})"; }

    std::string GenOffsetU32() { return "let o : UInt32 = UInt32({{ACCESS}}.offset({{OFFSET}}))"; }

    std::string GenTableBuf() { return "let buf = {{ACCESS}}.bytes"; }

    std::string GenReaderMainBody(const bool optional = false)
    {
        std::string res = "{{ACCESS_TYPE}}func {{VALUENAME}}(): ";
        if (optional) {
            res += "Option<{{VALUETYPE}}> {";
        } else {
            res += "{{VALUETYPE}} {";
        }
        return res;
    }

    std::string GenConstructor(const std::string& offset) { return "{{VALUETYPE}}({{ACCESS}}.bytes, " + offset + ")"; }

    std::string GenEnumDefaultValue(const FieldDef& field)
    {
        auto& value = field.value;
        FLATBUFFERS_ASSERT(value.type.enum_def);
        auto& enum_def = *value.type.enum_def;
        const auto& ev = **enum_def.Vals().begin();
        std::string name = enum_def.name + "_" + MakeScreamingCamel(ev.name);
        return "{{VALUETYPE}}." + name;
    }

    std::string GenEnumConstructor(const std::string& at) { return "{{VALUETYPE}}(" + GenIndirect(at) + ") "; }

    std::string ValidateFunc() { return "static func validateVersion() { FlatBuffersVersion_1_12_0() }"; }

    std::string GenType(const Type& type, const bool should_consider_suffix = false) const
    {
        auto ret = IsScalar(type.base_type) ? GenTypeBasic(type) : GenTypePointer(type, should_consider_suffix);
        ret = MakeCamelCase(ret);
        return ret;
    }

    std::string MakeCamelCase(const std::string s) const
    {
        if (!s.compare("uint8")) {
            return "UInt8";
        } else if (!s.compare("uint16")) {
            return "UInt16";
        } else if (!s.compare("uint32")) {
            return "UInt32";
        } else if (!s.compare("uint64")) {
            return "UInt64";
        } else if (!s.compare("int8")) {
            return "Int8";
        } else if (!s.compare("int16")) {
            return "Int16";
        } else if (!s.compare("int32")) {
            return "Int32";
        } else if (!s.compare("int64")) {
            return "Int64";
        } else if (!s.compare("float16")) {
            return "Float16";
        } else if (!s.compare("float32")) {
            return "Float32";
        } else if (!s.compare("float64")) {
            return "Float64";
        } else if (!s.compare("string")) {
            return "String";
        } else if (!s.compare("bool")) {
            return "Bool";
        } else if (!s.compare("unit")) {
            return "Unit";
        } else if (!s.compare("rune")) {
            return "Rune";
        } else if (!s.compare("nothing")) {
            return "Nothing";
        } else if (!s.compare("any")) {
            return "Any";
        } else {
            return s;
        }
    }

    std::string GenTypePointer(const Type& type, const bool should_consider_suffix) const
    {
        switch (type.base_type) {
            case BASE_TYPE_STRING:
                return "String";
            case BASE_TYPE_VECTOR:
                return GenType(type.VectorType());
            case BASE_TYPE_STRUCT: {
                auto& struct_ = *type.struct_def;
                if (should_consider_suffix) {
                    return WrapInNameSpace(struct_.defined_namespace, ObjectAPIName(Name(struct_)));
                }
                return WrapInNameSpace(struct_);
            }
            case BASE_TYPE_UNION:
            default:
                return "FlatBufferObject";
        }
    }

    std::string GenTypeBasic(const Type& type) const { return GenTypeBasic(type, true); }

    std::string ObjectAPIName(const std::string& name) const
    {
        return parser_.opts.object_prefix + name + parser_.opts.object_suffix;
    }

    void Indent() { code_.IncrementIdentLevel(); }

    void Outdent() { code_.DecrementIdentLevel(); }

    std::string NameWrappedInNameSpace(const EnumDef& enum_def) const
    {
        return WrapInNameSpace(enum_def.defined_namespace, MakeCamel(enum_def.name, false));
    }

    std::string NameWrappedInNameSpace(const StructDef& struct_def) const
    {
        return WrapInNameSpace(struct_def.defined_namespace, MakeCamel(struct_def.name, false));
    }

    std::string GenTypeBasic(const Type& type, bool can_override) const
    {
        // clang-format off
        static const char * const char_type[] = {
        #define FLATBUFFERS_TD(ENUM, IDLTYPE, \
                CTYPE, JTYPE, GTYPE, NTYPE, PTYPE, KTYPE, RTYPE, STYPE, CJTYPE, ...) \
        #CJTYPE,
            FLATBUFFERS_GEN_TYPES(FLATBUFFERS_TD)
        #undef FLATBUFFERS_TD
        };
        // clang-format on
        if (can_override) {
            if (type.enum_def) {
                return NameWrappedInNameSpace(*type.enum_def);
            }
            if (type.base_type == BASE_TYPE_BOOL) {
                return "Bool";
            }
        }
        return char_type[static_cast<int>(type.base_type)];
    }

    std::string EscapeKeyword(const std::string& name) const
    {
        return keywords_.find(name) == keywords_.end() ? name : name + "_";
    }

    std::string Name(const EnumVal& ev) const
    {
        auto name = ev.name;
        if (isupper(name.front())) {
            std::transform(name.begin(), name.end(), name.begin(), CharToLower);
        }
        return EscapeKeyword(MakeCamel(name, false));
    }

    std::string Name(const Definition& def) const { return EscapeKeyword(MakeCamel(def.name, false)); }
};
} // namespace cangjie

static bool GenerateCangjie(const Parser& parser, const std::string& path, const std::string& file_name)
{
    cangjie::CjGenerator generator(parser, path, file_name);
    return generator.generate();
}

namespace {

    class CangjieCodeGenerator : public CodeGenerator {
    public:
        Status GenerateCode(const Parser &parser, const std::string &path,
                            const std::string &filename) override {
            if (!GenerateCangjie(parser, path, filename)) { return Status::ERROR; }
            return Status::OK;
        }

        Status GenerateCode(const uint8_t *, int64_t,
                            const CodeGenOptions &) override {
            return Status::NOT_IMPLEMENTED;
        }

        Status GenerateGrpcCode(const Parser &parser, const std::string &path,
                                const std::string &filename) override {
            (void)parser;
            (void)path;
            (void)filename;
            return Status::NOT_IMPLEMENTED;
        }

        Status GenerateMakeRule(const Parser &parser, const std::string &path,
                                const std::string &filename,
                                std::string &output) override {
            (void)parser;
            (void)path;
            (void)filename;
            (void)output;
            return Status::NOT_IMPLEMENTED;
        }

        Status GenerateRootFile(const Parser &parser,
                                const std::string &path) override {
            (void)parser;
            (void)path;
            return Status::NOT_IMPLEMENTED;
        }

        bool IsSchemaOnly() const override { return true; }

        bool SupportsBfbsGeneration() const override { return false; }

        bool SupportsRootFileGeneration() const override { return false; }

        IDLOptions::Language Language() const override { return IDLOptions::kCangjie; }

        std::string LanguageName() const override { return "Cangjie"; }
    };
}

std::unique_ptr<CodeGenerator> NewCangjieCodeGenerator() {
    return std::unique_ptr<CangjieCodeGenerator>(new CangjieCodeGenerator());
}
} // namespace flatbuffers
