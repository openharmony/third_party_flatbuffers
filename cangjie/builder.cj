// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

package std.ast

import std.collection.{HashMap, ArrayList}
import std.sort.sort

const INITIAL_VTABLE_NUM = 16

/*
 * Builder manages an Array<UInt8> in which stores vtable representing fbs table.
 */
class Builder {
    private var bytes: Array<UInt8>                     // byte array to store vtable.
    private var minAlign: Int64                         // current alignment rule.
    private var currentVtable: ArrayList<UInt32>       // memory object of current table.
    private var objectEnd: UInt32                       // end position of current table
    private var offsetsOfVtables: ArrayList<UInt32>     // list of offsets of all vtables.
    private var head: UInt32                            // start position of used byte array.
    private var nested: Bool                            // if is currently serializing a table.
    private var finished: Bool                          // if the byte array is finished.
    private var sharedStrings: HashMap<String, UInt32>  // map of created strings.

    init(initialSize: Int64) {
        let size = if (initialSize <= 0) {
            0
        } else {
            initialSize
        }
        this.bytes = Array<UInt8>(size, repeat: 0)
        this.head = UInt32(size)
        this.minAlign = 1
        this.offsetsOfVtables = ArrayList<UInt32>(INITIAL_VTABLE_NUM)
        this.currentVtable = ArrayList<UInt32>()
        this.nested = false
        this.finished = false
        this.objectEnd = 0
        this.sharedStrings = HashMap<String, UInt32>()
    }

    /*
     * Reset builder.
     */
    func reset() {
        // Reset to full capacity
        this.bytes.fill(0)
        this.offsetsOfVtables.clear()
        this.currentVtable.clear()
        this.sharedStrings.clear()
        this.head = UInt32(this.bytes.size)
        this.minAlign = 1
        this.nested = false
        this.finished = false
    }

    /*
     * Returns used part of byte array.
     */
    func finishedBytes(): Array<UInt8> {
        this.assertFinished()
        this.bytes[Int64(this.head)..]
    }

    /*
     * Start a new vtable for a table object.
     */
    func startObject(numFields: Int64): Unit {
        this.assertNotNested()
        this.nested = true

        if (this.currentVtable.size < numFields || this.currentVtable.size == 0) {
            this.currentVtable = ArrayList<UInt32>(numFields, { _ => 0 })
        } else {
            this.currentVtable = this.currentVtable[..numFields]
            for (i in 0..this.currentVtable.size) {
                this.currentVtable[i] = 0
            }
        }
        this.objectEnd = this.offset()
    }

    /*
     * Serializes the vtable for current object.
     */
    private func writeVtable(): UInt32 {
        // pre-allocate a place for vtable offset.
        this.prependSOffsetT(0)

        let objectOffset = this.offset()
        var existingVtable: UInt32 = 0

        var i = this.currentVtable.size - 1
        while (i >= 0 && this.currentVtable[i] == 0) {
            i--
        }
        this.currentVtable = this.currentVtable[..i + 1]

        // search for existing identical vtable.
        for (i in this.offsetsOfVtables.size - 1..=0 : -1) {
            let vt2Offset = this.offsetsOfVtables[i]
            let vt2Start = this.bytes.size - Int64(vt2Offset)
            let vt2Len = getUInt16(this.bytes[vt2Start..])

            let metadata = VTABLE_METADATA_FIELDS * SIZE_UINT16
            let vt2End = vt2Start + Int64(vt2Len)
            let vt2Slice = this.bytes[vt2Start + Int64(metadata)..vt2End]

            if (vtableEqual(this.currentVtable, objectOffset, vt2Slice)) {
                existingVtable = vt2Offset
                break
            }
        }

        if (existingVtable == 0) {
            // Cannot find existing vtable, write current vtable to byte array.
            for (i in this.currentVtable.size - 1..=0 : -1) {
                var off: UInt32 = 0
                if (this.currentVtable[i] != 0) {
                    off = objectOffset - this.currentVtable[i]
                }
                this.prependUInt16(UInt16(off))
            }

            // object size
            let objectSize = objectOffset - this.objectEnd
            this.prependUInt16(UInt16(objectSize))

            // vtable size
            let vBytes = (this.currentVtable.size + VTABLE_METADATA_FIELDS) * SIZE_VOFFSET_T
            this.prependUInt16(UInt16(vBytes))

            // already-allocated offset
            let objectStart = Int32(this.bytes.size) - Int32(objectOffset)
            writeInt32(this.bytes[Int64(objectStart)..],
                Int32(this.offset()) - Int32(objectOffset))

            this.offsetsOfVtables.add(this.offset())
        } else {
            // Found an identical vtable, 
            let objectStart = Int32(this.bytes.size) - Int32(objectOffset)
            this.head = UInt32(objectStart)

            // already-allocated offset
            writeInt32(this.bytes[Int64(this.head)..],
                Int32(existingVtable) - Int32(objectOffset))
        }

        this.currentVtable.clear()
        return objectOffset
    }

    /*
     * Finish object construction.
     */
    func endObject(): UInt32 {
        this.assertNested()
        let n = this.writeVtable()
        this.nested = false
        return n
    }

    /*
     * Grows the size of byte array.
     */
    private func growByteBuffer(): Unit {
        if ((this.bytes.size & 0xC0000000) != 0) {
            throw FlatBuffersException("cannot grow buffer beyond 2 GB")
        }
        var newLen = this.bytes.size * 2
        if (newLen == 0) {
            newLen = 1
        }

        let oldBytes = this.bytes
        this.bytes = Array<UInt8>(newLen, repeat: 0)

        // data copy
        let oldSize = oldBytes.size
        let copyStart = newLen - oldSize
        for (i in 0..oldSize) {
            this.bytes[copyStart + i] = oldBytes[i]
        }

        this.bytes = Array<UInt8>(this.bytes.size, repeat: 0).concat(this.bytes)
    }

    func getHead(): UInt32 {
        this.head
    }

    func offset(): UInt32 {
        return UInt32(this.bytes.size) - this.head
    }

    /*
     * Places zeros at the current offset.
     */
    func pad(n: Int64): Unit {
        for (_ in 0..n) {
            this.placeUInt8(0)
        }
    }

    /*
     * Pre-allocate bytes needed.
     */
    func prep(size: Int64, additionalBytes: Int64): Unit {
        // Track the biggest thing we've ever aligned to
        if (size > this.minAlign) {
            this.minAlign = size
        }

        // find the amount of alignment needed
        var alignSize: Int64 = (!(this.bytes.size - Int64(this.head) + additionalBytes)) + 1
        alignSize &= (size - 1)

        // grow byte array if needed
        while (Int64(this.head) <= alignSize + size + additionalBytes) {
            let oldBufSize = this.bytes.size
            this.growByteBuffer()
            this.head += UInt32(this.bytes.size - oldBufSize)
        }
        this.pad(alignSize)
    }

    /*
     * Prepends a signed offset for future vtable finding.
     */
    func prependSOffsetT(off: Int32): Unit {
        this.prep(SIZE_SOFFSET_T, 0)
        if (!(UInt32(off) <= this.offset())) {
            throw FlatBuffersException("unreachable: off <= offset()")
        }
        let off2 = Int32(this.offset()) - off + Int32(SIZE_INT32)
        this.placeInt32(off2)
    }

    /*
     * Prepends an unsigned offset for future table field finding.
     */
    func prependUOffsetT(off: UInt32): Unit {
        this.prep(SIZE_UOFFSET_T, 0)
        if (!(off <= this.offset())) {
            throw FlatBuffersException("unreachable: off <= offset()")
        }
        let off2 = this.offset() - off + UInt32(SIZE_UOFFSET_T)
        this.placeUInt32(off2)
    }

    /*
     * Start a new vector of struct or primitive types.
     */
    func startVector(elemSize: Int64, numElems: Int64, alignment: Int64): UInt32 {
        this.assertNotNested()
        this.nested = true
        this.prep(SIZE_UINT32, elemSize * numElems)
        // in case alignment size is greater than size of int.
        this.prep(alignment, elemSize * numElems)
        return this.offset()
    }

    /*
     * Finish vector construction.
     */
    func endVector(vectorNumElems: Int64): UInt32 {
        this.assertNested()
        this.placeUInt32(UInt32(vectorNumElems))
        this.nested = false
        return this.offset()
    }

    /*
     * Start a new vector of tables and store their offsets.
     */
    func createVectorOfTables(offsets: Array<UInt32>): UInt32 {
        this.assertNotNested()
        this.startVector(4, offsets.size, 4)
        for (i in offsets.size - 1..=0 : -1) {
            this.prependUOffsetT(offsets[i])
        }
        return this.endVector(offsets.size)
    }

    /*
     * Returns offset of existing identical string or create a new one.
     */
    func createSharedString(s: String): UInt32 {
        if (this.sharedStrings.contains(s)) {
            return this.sharedStrings[s]
        }
        let off = this.createString(s)
        this.sharedStrings[s] = off
        return off
    }

    /*
     * Create a string and return its offset.
     */
    func createString(s: String): UInt32 {
        this.assertNotNested()
        this.nested = true

        let bytes = s.toArray()
        this.prep(SIZE_UOFFSET_T, (bytes.size + 1) * SIZE_UINT8)
        this.placeUInt8(0)

        let l = UInt32(bytes.size)

        this.head -= l
        // copy string
        bytes.copyTo(this.bytes[Int64(this.head)..])

        return this.endVector(bytes.size)
    }

    /*
     * Create a byte string and return its offset.
     */
    func createByteString(s: Array<UInt8>): UInt32 {
        this.assertNotNested()
        this.nested = true

        this.prep(SIZE_UOFFSET_T, (s.size + 1) * SIZE_UINT8)
        this.placeUInt8(0)

        let l = UInt32(s.size)

        this.head -= l
        // copy bytes
        s.copyTo(this.bytes[Int64(this.head)..])

        return this.endVector(s.size)
    }

    /*
     * Create a byte vector and return its offset.
     */
    func createByteVector(v: Array<UInt8>): UInt32 {
        this.assertNotNested()
        this.nested = true

        this.prep(SIZE_UOFFSET_T, v.size * SIZE_UINT8)

        let l = UInt32(v.size)

        this.head -= l
        // Copy bytes
        v.copyTo(this.bytes[Int64(this.head)..])

        return this.endVector(v.size)
    }

    /*
     * Assert that we are currently serializing an object.
     */
    private func assertNested(): Unit {
        if (!this.nested) {
            throw FlatBuffersException("Incorrect creation order: must be inside object.")
        }
    }

    /*
     * Assert that we are not currently serializing an object.
     */
    private func assertNotNested(): Unit {
        if (this.nested) {
            throw FlatBuffersException("Incorrect creation order: object must not be nested.")
        }
    }

    /*
     * Assert that we are finishing byte array.
     */
    private func assertFinished(): Unit {
        if (!this.finished) {
            throw FlatBuffersException("Incorrect use of finishedBytes(): must call 'finish' first.")
        }
    }

    func prependBoolSlot(o: Int64, x: Bool, default: Bool): Unit {
        let val: UInt8 = if (x) {
            1
        } else {
            0
        }
        let def: UInt8 = if (default) {
            1
        } else {
            0
        }
        this.prependUInt8Slot(o, val, def)
    }

    func prependUInt8Slot(o: Int64, x: UInt8, default: UInt8): Unit {
        if (x != default) {
            this.prependUInt8(x)
            this.slot(o)
        }
    }

    func prependUInt16Slot(o: Int64, x: UInt16, default: UInt16): Unit {
        if (x != default) {
            this.prependUInt16(x)
            this.slot(o)
        }
    }

    func prependUInt32Slot(o: Int64, x: UInt32, default: UInt32): Unit {
        if (x != default) {
            this.prependUInt32(x)
            this.slot(o)
        }
    }

    func prependUInt64Slot(o: Int64, x: UInt64, default: UInt64): Unit {
        if (x != default) {
            this.prependUInt64(x)
            this.slot(o)
        }
    }

    func prependInt8Slot(o: Int64, x: Int8, default: Int8): Unit {
        if (x != default) {
            this.prependInt8(x)
            this.slot(o)
        }
    }

    func prependInt16Slot(o: Int64, x: Int16, default: Int16): Unit {
        if (x != default) {
            this.prependInt16(x)
            this.slot(o)
        }
    }

    func prependInt32Slot(o: Int64, x: Int32, default: Int32): Unit {
        if (x != default) {
            this.prependInt32(x)
            this.slot(o)
        }
    }

    func prependInt64Slot(o: Int64, x: Int64, default: Int64): Unit {
        if (x != default) {
            this.prependInt64(x)
            this.slot(o)
        }
    }

    func prependFloat32Slot(o: Int64, x: Float32, default: Float32): Unit {
        if (x != default) {
            this.prependFloat32(x)
            this.slot(o)
        }
    }

    func prependFloat64Slot(o: Int64, x: Float64, default: Float64): Unit {
        if (x != default) {
            this.prependFloat64(x)
            this.slot(o)
        }
    }

    func prependUOffsetTSlot(o: Int64, x: UInt32, default: UInt32): Unit {
        if (x != default) {
            this.prependUOffsetT(x)
            this.slot(o)
        }
    }

    func prependStructSlot(voffset: Int64, x: UInt32, default: UInt32): Unit {
        if (x != default) {
            this.assertNested()
            if (x != this.offset()) {
                throw FlatBuffersException("inline data write outside of object")
            }
            this.slot(voffset)
        }
    }

    /*
     * Sets the offset of current field to current location in byte array.
     */
    private func slot(slotNum: Int64): Unit {
        if (slotNum < this.currentVtable.size) {
            this.currentVtable[slotNum] = this.offset()
        } else {
            throw FlatBuffersException("slot receives a slotNum larger than vtable.size")
        }
    }

    /*
     * Finalizes byte array for root table with a file identifier.
     */
    func finishWithFileIdentifier(rootTable: UInt32, fid: Array<UInt8>): Unit {
        if (fid.size != FILE_IDENTIFIER_LENGTH) {
            throw FlatBuffersException("incorrect file identifier length")
        }
        this.prep(this.minAlign, SIZE_INT32 + FILE_IDENTIFIER_LENGTH)
        for (i in FILE_IDENTIFIER_LENGTH - 1..=0 : -1) {
            this.placeUInt8(fid[i])
        }
        this.finish(rootTable)
    }

    /*
     * Finalizes byte array for root table with a prefix representing size of array.
     */
    func finishSizePrefixed(rootTable: UInt32): Unit {
        this.finishInternal(rootTable, true)
    }

    /*
     * Finalizes byte array for root table with a prefix representing size of array and file identifier.
     */
    func finishSizePrefixedWithFileIdentifier(rootTable: UInt32, fid: Array<UInt8>): Unit {
        if (fid.size != FILE_IDENTIFIER_LENGTH) {
            throw FlatBuffersException("incorrect file identifier length")
        }
        this.prep(this.minAlign, SIZE_INT32 + FILE_IDENTIFIER_LENGTH + SIZE_PREFIX_LENGTH)
        for (i in FILE_IDENTIFIER_LENGTH - 1..=0 : -1) {
            this.placeUInt8(fid[i])
        }
        this.finishInternal(rootTable, true)
    }

    /*
     * Finalizes byte array for root table.
     */
    func finish(rootTable: UInt32): Unit {
        this.finishInternal(rootTable, false)
    }

    /*
     * Finalizes byte array for root table with optional prefix of array size.
     */
    private func finishInternal(rootTable: UInt32, sizePrefix: Bool): Unit {
        this.assertNotNested()

        if (sizePrefix) {
            this.prep(this.minAlign, SIZE_UINT32 + SIZE_PREFIX_LENGTH)
        } else {
            this.prep(this.minAlign, SIZE_UINT32)
        }

        this.prependUOffsetT(rootTable)

        if (sizePrefix) {
            this.placeUInt32(UInt32(this.offset()))
        }

        this.finished = true
    }

    func prependBool(x: Bool): Unit {
        this.prep(SIZE_BOOL, 0)
        this.placeBool(x)
    }

    func prependUInt8(x: UInt8): Unit {
        this.prep(SIZE_UINT8, 0)
        this.placeUInt8(x)
    }

    func prependUInt16(x: UInt16): Unit {
        this.prep(SIZE_UINT16, 0)
        this.placeUInt16(x)
    }

    func prependUInt32(x: UInt32): Unit {
        this.prep(SIZE_UINT32, 0)
        this.placeUInt32(x)
    }

    func prependUInt64(x: UInt64): Unit {
        this.prep(SIZE_UINT64, 0)
        this.placeUInt64(x)
    }

    func prependInt8(x: Int8): Unit {
        this.prep(SIZE_INT8, 0)
        this.placeInt8(x)
    }

    func prependInt16(x: Int16): Unit {
        this.prep(SIZE_INT16, 0)
        this.placeInt16(x)
    }

    func prependInt32(x: Int32): Unit {
        this.prep(SIZE_INT32, 0)
        this.placeInt32(x)
    }

    func prependInt64(x: Int64): Unit {
        this.prep(SIZE_INT64, 0)
        this.placeInt64(x)
    }

    func prependFloat32(x: Float32): Unit {
        this.prep(SIZE_FLOAT32, 0)
        this.placeFloat32(x)
    }

    func prependFloat64(x: Float64): Unit {
        this.prep(SIZE_FLOAT64, 0)
        this.placeFloat64(x)
    }

    func prependVOffsetT(x: UInt16): Unit {
        this.prep(SIZE_VOFFSET_T, 0)
        this.placeVOffsetT(x)
    }

    func placeBool(x: Bool): Unit {
        this.head -= UInt32(SIZE_BOOL)
        writeBool(this.bytes[Int64(this.head)..], x)
    }

    func placeUInt8(x: UInt8): Unit {
        this.head -= UInt32(SIZE_UINT8)
        writeUInt8(this.bytes[Int64(this.head)..], x)
    }

    func placeUInt16(x: UInt16): Unit {
        this.head -= UInt32(SIZE_UINT16)
        writeUInt16(this.bytes[Int64(this.head)..], x)
    }

    func placeUInt32(x: UInt32): Unit {
        this.head -= UInt32(SIZE_UINT32)
        writeUInt32(this.bytes[Int64(this.head)..], x)
    }

    func placeUInt64(x: UInt64): Unit {
        this.head -= UInt32(SIZE_UINT64)
        writeUInt64(this.bytes[Int64(this.head)..], x)
    }

    func placeInt8(x: Int8): Unit {
        this.head -= UInt32(SIZE_INT8)
        writeInt8(this.bytes[Int64(this.head)..], x)
    }

    func placeInt16(x: Int16): Unit {
        this.head -= UInt32(SIZE_INT16)
        writeInt16(this.bytes[Int64(this.head)..], x)
    }

    func placeInt32(x: Int32): Unit {
        this.head -= UInt32(SIZE_INT32)
        writeInt32(this.bytes[Int64(this.head)..], x)
    }

    func placeInt64(x: Int64): Unit {
        this.head -= UInt32(SIZE_INT64)
        writeInt64(this.bytes[Int64(this.head)..], x)
    }

    func placeFloat32(x: Float32): Unit {
        this.head -= UInt32(SIZE_FLOAT32)
        writeFloat32(this.bytes[Int64(this.head)..], x)
    }

    func placeFloat64(x: Float64): Unit {
        this.head -= UInt32(SIZE_FLOAT64)
        writeFloat64(this.bytes[Int64(this.head)..], x)
    }

    func placeVOffsetT(x: UInt16): Unit {
        this.head -= UInt32(SIZE_VOFFSET_T)
        writeUInt16(this.bytes[Int64(this.head)..], x)
    }

    func placeSOffsetT(x: Int32): Unit {
        this.head -= UInt32(SIZE_SOFFSET_T)
        writeInt32(this.bytes[Int64(this.head)..], x)
    }

    func placeUOffsetT(x: UInt32): Unit {
        this.head -= UInt32(SIZE_UOFFSET_T)
        writeUInt32(this.bytes[Int64(this.head)..], x)
    }
}

/*
 * Compares unwritten vtable to one that already in byte array slice.
 */
private func vtableEqual(a: ArrayList<UInt32>, objectStart: UInt32, b: Array<UInt8>): Bool {
    if (a.size * SIZE_UINT16 != b.size) {
        return false
    }

    for (i in 0..a.size) {
        let x = getUInt16(b[i * SIZE_UINT16 .. (i + 1) * SIZE_UINT16])

        // Skip field with default value
        if (x == 0 && a[i] == UInt32(0)) {
            continue
        }

        let y = Int32(objectStart) - Int32(a[i])
        if (Int32(x) != y) {
            return false
        }
    }
    return true
}
