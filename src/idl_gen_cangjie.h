// This source file is part of the Cangjie project.
//
// Copyright (c) 2025 Huawei Technologies Co., Ltd. and the Cangjie project authors.
// Licensed under Apache-2.0 with Runtime Library Exceptions.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information

#ifndef CANGJIE_IDL_GEN_CANGJIE_H
#define CANGJIE_IDL_GEN_CANGJIE_H

#include "flatbuffers/code_generator.h"

namespace flatbuffers {

// Constructs a new Cpp code generator.
    std::unique_ptr<CodeGenerator> NewCangjieCodeGenerator();

}  // namespace flatbuffers


#endif //CANGJIE_IDL_GEN_CANGJIE_H
