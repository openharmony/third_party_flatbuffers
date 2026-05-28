// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

import std.fs.File

type Struct0 = Test_Struct0
type Table0 = Test_Table0

@Test
class Test {
    var bytes = Array<UInt8>()

    @BeforeAll
    func writeTable0() {
        bytes = File.readFrom("./test.buf")
    }

    @TestCase
    func testStruct() {
        let table0 = Table0(bytes, 0)
        let struct0 = table0.GetSss()
        @Expect(struct0.aaa, 0)
        @Expect(struct0.bbb, false)
    }

    @TestCase
    func testString() {
        let table0 = Table0(bytes, 0)
        let str = table0.GetStr()
        @Expect(str, "")
    }
}