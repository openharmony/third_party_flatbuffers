// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
 
package std.ast
public open class FlatBufferObject {
    let table: Table

    public init(buf: Array<UInt8>, root: UInt32) {
        let offset: UInt32 = if (buf.size > Int64(root) + 4) {
            getUInt32(buf[Int64(root)..Int64(root) + 4]) }
        else {
            UInt32(0)
        }
        this.table = Table(buf, offset + root)
    }
}
