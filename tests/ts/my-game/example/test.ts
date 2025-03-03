// automatically generated by the FlatBuffers compiler, do not modify

/* eslint-disable @typescript-eslint/no-unused-vars, @typescript-eslint/no-explicit-any, @typescript-eslint/no-non-null-assertion */

import * as flatbuffers from 'flatbuffers';



export class Test implements flatbuffers.IUnpackableObject<TestT> {
  bb: flatbuffers.ByteBuffer|null = null;
  bb_pos = 0;
  __init(i:number, bb:flatbuffers.ByteBuffer):Test {
  this.bb_pos = i;
  this.bb = bb;
  return this;
}

a():number {
  return this.bb!.readInt16(this.bb_pos);
}

mutate_a(value:number):boolean {
  this.bb!.writeInt16(this.bb_pos + 0, value);
  return true;
}

b():number {
  return this.bb!.readInt8(this.bb_pos + 2);
}

mutate_b(value:number):boolean {
  this.bb!.writeInt8(this.bb_pos + 2, value);
  return true;
}

static getFullyQualifiedName():string {
  return 'MyGame.Example.Test';
}

static sizeOf():number {
  return 4;
}

static createTest(builder:flatbuffers.Builder, a: number, b: number):flatbuffers.Offset {
  builder.prep(2, 4);
  builder.pad(1);
  builder.writeInt8(b);
  builder.writeInt16(a);
  return builder.offset();
}


unpack(): TestT {
  return new TestT(
    this.a(),
    this.b()
  );
}


unpackTo(_o: TestT): void {
  _o.a = this.a();
  _o.b = this.b();
}
}

export class TestT implements flatbuffers.IGeneratedObject {
constructor(
  public a: number = 0,
  public b: number = 0
){}


pack(builder:flatbuffers.Builder): flatbuffers.Offset {
  return Test.createTest(builder,
    this.a,
    this.b
  );
}
}
