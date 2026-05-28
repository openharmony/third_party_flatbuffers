// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

#include "struct_and_string_generated.h"
#include <fstream>

int main() {
    flatbuffers::FlatBufferBuilder fbb;
    auto table0 = Test::CreateTable0(fbb);
    Test::FinishTable0Buffer(fbb, table0);
    size_t buffer_size = fbb.GetSize();
    const uint8_t* buffer = fbb.GetBufferPointer();

    auto file_path = "./test.buf";
    std::ofstream out_file(file_path, std::ios::out | std::ios::binary);
    out_file.write(reinterpret_cast<const char*>(buffer), buffer_size);
    out_file.close();
    return 0;
}