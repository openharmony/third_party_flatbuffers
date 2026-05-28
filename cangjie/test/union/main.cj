// Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

import std.fs.File

type Union0 = Test_Union0
type Table0 = Test_Table0

@Test
class Test {
    var bytes = Array<UInt8>()

    @BeforeAll
    func writeTable0() {
        bytes = File.readFrom("./test.buf")
    }

    @TestCase
    func testUnion() {
        let table0 = Table0(bytes, 0)
        let union0Type = table0.GetUuuType()
        match (union0Type) {
            case Union0_SSS => @Expect(true)
            case _ => @Expect(false)
        }
        let str = table0.GetUuuAsString()
        match (str) {
            case Some(s) => @Expect(s, "flatbuffers")
            case _ => @Expect(false)
        }
    }
}