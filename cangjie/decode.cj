// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

package std.ast
func boundsCheck(buf: Array<UInt8>, sz: Int64): Bool {
    if (sz < 0 || sz > buf.size) {
        throw IndexOutOfBoundsException("sz is ${sz} but buf size is ${buf.size}")
    }
    return true
}

func getUInt8(buf: Array<UInt8>): UInt8 {
    boundsCheck(buf, 1)
    return buf[0]
}

@OverflowWrapping
func getInt8(buf: Array<UInt8>): Int8 {
    return Int8(getUInt8(buf))
}

func getBool(buf: Array<UInt8>): Bool {
    boundsCheck(buf, 1)
    return buf[0] == 1
}

func getUInt16(buf: Array<UInt8>): UInt16 {
    boundsCheck(buf, 2)
    var num: UInt16 = UInt16(buf[0])
    num = num | UInt16(buf[1]) << 8
    return num
}

@OverflowWrapping
func getInt16(buf: Array<UInt8>): Int16 {
    return Int16(getUInt16(buf))
}

func getUInt32(buf: Array<UInt8>): UInt32 {
    boundsCheck(buf, 4)
    var num: UInt32 = UInt32(buf[0])
    num = num | UInt32(buf[1]) << 8
    num = num | UInt32(buf[2]) << 16
    num = num | UInt32(buf[3]) << 24
    return num
}

// used in stdlib/ast directly
@OverflowWrapping
func getInt32(buf: Array<UInt8>): Int32 {
    return Int32(getUInt32(buf))
}

func getUInt64(buf: Array<UInt8>): UInt64 {
    boundsCheck(buf, 8)
    var num: UInt64 = UInt64(buf[0])
    num = num | UInt64(buf[1]) << 8
    num = num | UInt64(buf[2]) << 16
    num = num | UInt64(buf[3]) << 24
    num = num | UInt64(buf[4]) << 32
    num = num | UInt64(buf[5]) << 40
    num = num | UInt64(buf[6]) << 48
    num = num | UInt64(buf[7]) << 56
    return num
}

@OverflowWrapping
func getInt64(buf: Array<UInt8>): Int64 {
    return Int64(getUInt64(buf))
}

func getString(buf: Array<UInt8>, offset: Int64, len: UInt32): String {
    var end: Int64 = offset + Int64(len)
    boundsCheck(buf, end)
    return String.fromUtf8(buf[offset..end])
}

func getFloat32(buf: Array<UInt8>): Float32 {
    return Float32.fromBits(getUInt32(buf))
}

func getFloat64(buf: Array<UInt8>): Float64 {
    return Float64.fromBits(getUInt64(buf))
}

func writeUInt8(buf: Array<UInt8>, n: UInt8) {
    boundsCheck(buf, 1)
    buf[0] = n
}

func writeInt8(buf: Array<UInt8>, n: Int8) {
    boundsCheck(buf, 1)
    buf[0] = UInt8(n)
}

func writeBool(buf: Array<UInt8>, n: Bool) {
    boundsCheck(buf, 1)
    buf[0] = if (n) {
        1
    } else {
        0
    }
}

@OverflowWrapping
func writeUInt16(buf: Array<UInt8>, n: UInt16) {
    boundsCheck(buf, 2)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
}

@OverflowWrapping
func writeInt16(buf: Array<UInt8>, n: Int16) {
    boundsCheck(buf, 2)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
}

@OverflowWrapping
func writeUInt32(buf: Array<UInt8>, n: UInt32) {
    boundsCheck(buf, 4)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
    buf[2] = UInt8(n >> 16)
    buf[3] = UInt8(n >> 24)
}

@OverflowWrapping
func writeInt32(buf: Array<UInt8>, n: Int32) {
    boundsCheck(buf, 4)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
    buf[2] = UInt8(n >> 16)
    buf[3] = UInt8(n >> 24)
}

@OverflowWrapping
func writeUInt64(buf: Array<UInt8>, n: UInt64) {
    boundsCheck(buf, 8)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
    buf[2] = UInt8(n >> 16)
    buf[3] = UInt8(n >> 24)
    buf[4] = UInt8(n >> 32)
    buf[5] = UInt8(n >> 40)
    buf[6] = UInt8(n >> 48)
    buf[7] = UInt8(n >> 56)
}

@OverflowWrapping
func writeInt64(buf: Array<UInt8>, n: Int64) {
    boundsCheck(buf, 8)
    buf[0] = UInt8(n)
    buf[1] = UInt8(n >> 8)
    buf[2] = UInt8(n >> 16)
    buf[3] = UInt8(n >> 24)
    buf[4] = UInt8(n >> 32)
    buf[5] = UInt8(n >> 40)
    buf[6] = UInt8(n >> 48)
    buf[7] = UInt8(n >> 56)
}

func writeFloat32(buf: Array<UInt8>, n: Float32) {
    writeUInt32(buf, n.toBits())
}

func writeFloat64(buf: Array<UInt8>, n: Float64) {
    writeUInt64(buf, n.toBits())
}