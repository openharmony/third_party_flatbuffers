// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.

type Vec11 = MyGame_Sample_Vec11
type Monster = MyGame_Sample_Monster
type Color = MyGame_Sample_Color
type Equipment = MyGame_Sample_Equipment
type Weapon = MyGame_Sample_Weapon
type Shield = MyGame_Sample_Shield
type Gem = MyGame_Sample_Gem

@Test
class Test {
    var arr = Array<UInt8>()
    var fb = Builder(0)

    @BeforeAll
    func writeMonster() {
        // create a vector for Monster.path field
        fb.startVector(48, 2, 8)
        let vec11_1 = createMyGame_Sample_Vec11(fb, Vec11(2, false, 4, 3, 1, 4, 5, 6, 7, 3.14, 3.14159))
        let vec11_2 = createMyGame_Sample_Vec11(fb, Vec11(3, false, 6, 3, 2, 4, 5, 6, 7, 6.28, 6.28318))
        let path = fb.endVector(2)
        let gem0 = Gem.createGem(fb, 6.28)
        let gem1 = Gem.createGem(fb, 9.42)
        let gem2 = Gem.createGem(fb, 12.56)
        let gem3 = Gem.createGem(fb, 7.7)
        let gem4 = Gem.createGem(fb, 8.8)
        let gem5 = Gem.createGem(fb, 9.9)
        let weapon_name0 = fb.createString("weapon0")
        let weapon_name1 = fb.createString("weapon1")
        let weapon_name2 = fb.createString("weapon2")
        let weapon0 = Weapon.createWeapon(fb, weapon_name0, 3, gem0)
        let weapon1 = Weapon.createWeapon(fb, weapon_name1, 5, gem1)
        let weapon2 = Weapon.createWeapon(fb, weapon_name2, 7, gem2)
        let shield_name0 = fb.createString("shield0")
        let shield_name1 = fb.createString("shield1")
        let shield_name2 = fb.createString("shield2")
        let shield0 = Shield.createShield(fb, shield_name0, 10.0, MyGame_Sample_Color.Color_GREEN, gem3)
        let shield1 = Shield.createShield(fb, shield_name1, 20.0, MyGame_Sample_Color.Color_BLUE, gem4)
        let shield2 = Shield.createShield(fb, shield_name2, 30.0, MyGame_Sample_Color.Color_RED, gem5)
        let weapons = fb.createVectorOfTables([weapon0, weapon1])
        // let shields = fb.createVectorOfTables([shield0, shield1])
        let monster_name = fb.createString("ORC")
        // create a vector for Monster.colorList field
        fb.startVector(4, 3, 4)
        for (i in 2..=0 : -1) {
            fb.prependUInt32(UInt32(i))
        }
        let color_list = fb.endVector(3)
        // create vectors for Monster.list field
        fb.startVector(1, 2, 1)
        fb.prependUInt8(EnumMyGame_Sample_EquipmentValues(MyGame_Sample_Equipment.Equipment_WEAPON))
        fb.prependUInt8(EnumMyGame_Sample_EquipmentValues(MyGame_Sample_Equipment.Equipment_SHIELD))
        let listTypes = fb.endVector(2)
        fb.startVector(4, 2, 4)
        fb.prependUOffsetT(weapon2)
        fb.prependUOffsetT(shield1)
        let list = fb.endVector(2)
        // create a vector for Monster.inventory field
        fb.startVector(1, 3, 1)
        fb.prependUInt8(44)
        fb.prependUInt8(55)
        fb.prependUInt8(66)
        let inventory = fb.endVector(3)
        let tmp_monster = Monster.createMonster(
            fb, Vec11(1, true, 2, 3, 2147483647, 4, 5, 6, 7, 3.14, 3.14159),
            1, false, 2, 3, 100, 4, 5, 6, 7, 0x1.1p3, Float64.Inf,
            monster_name, inventory, Color.Color_RED, color_list, weapon2, weapons, shield0, Equipment.Equipment_SHIELD, shield0, listTypes, list, path)
        
        fb.finish(tmp_monster)
        arr = fb.finishedBytes()
    }

    @TestCase
    func testPrimitive() {
        let monster = Monster(fb.finishedBytes(), 0)
        @Expect(monster.GetM0(), 1)
        @Expect(monster.GetM1(), false)
        @Expect(monster.GetM2(), 2)
        @Expect(monster.GetM3(), 3)
        @Expect(monster.GetM4(), 100)
        @Expect(monster.GetM5(), 4)
        @Expect(monster.GetM6(), 5)
        @Expect(monster.GetM7(), 6)
        @Expect(monster.GetM8(), 7)
        @Expect(monster.GetM9(), 0x1.1p3)
        @Expect(monster.GetM10(), Float64.Inf)
    }

    @TestCase
    func testString() {
        let monster = Monster(fb.finishedBytes(), 0)
        @Expect(monster.GetName(), "ORC")
    }

    @TestCase
    func testVector() {
        let monster = Monster(fb.finishedBytes(), 0)
        let inv = monster.GetInventory()
        @Expect(inv.size, 3)
        @Expect(inv.toString(), "[66, 55, 44]")
    }

    @TestCase
    func testStruct() {
        let monster = Monster(fb.finishedBytes(), 0)
        let vec11 = monster.GetPos()
        @Expect(vec11.v0, 1)
        @Expect(vec11.v1, true)
        @Expect(vec11.v2, 2)
        @Expect(vec11.v3, 3)
        @Expect(vec11.v4, 2147483647)
        @Expect(vec11.v5, 4)
        @Expect(vec11.v6, 5)
        @Expect(vec11.v7, 6)
        @Expect(vec11.v8, 7)
        @Expect(vec11.v9, 3.14)
        @Expect(vec11.v10, 3.14159)
    }

    @TestCase
    func testEnum() {
        let monster = Monster(fb.finishedBytes(), 0)
        let c = monster.GetColor()
        @Expect(EnumMyGame_Sample_ColorValues(c), 0)
    }

    @TestCase
    func testEnumVector() {
        let monster = Monster(fb.finishedBytes(), 0)
        let cList = monster.GetColorList()
        @Expect(cList.size, 3)
        @Expect(EnumMyGame_Sample_ColorValues(cList[0].getOrThrow()), 0)
        @Expect(EnumMyGame_Sample_ColorValues(cList[1].getOrThrow()), 1)
        @Expect(EnumMyGame_Sample_ColorValues(cList[2].getOrThrow()), 2)
    }

    @TestCase
    func testTableNest() {
        let monster = Monster(fb.finishedBytes(), 0)
        let curWeapon = monster.GetCurWeapon().getOrThrow()
        @Expect(curWeapon.GetName(), "weapon2")
        @Expect(curWeapon.GetDamage(), 7)
        @Expect(curWeapon.GetAux().getOrThrow().GetSize(), 12.56)
    }

    @TestCase
    func testTableVector() {
        let monster = Monster(fb.finishedBytes(), 0)
        let wps = monster.GetWeapons()
        @Expect(wps.size, 2)
        @Expect(wps[0].getOrThrow().GetName(), "weapon0")
        @Expect(wps[0].getOrThrow().GetDamage(), 3)
        @Expect(wps[0].getOrThrow().GetAux().getOrThrow().GetSize(), 6.28)
        @Expect(wps[1].getOrThrow().GetName(), "weapon1")
        @Expect(wps[1].getOrThrow().GetDamage(), 5)
        @Expect(wps[1].getOrThrow().GetAux().getOrThrow().GetSize(), 9.42)
    }

    @TestCase
    func testUnion() {
        let monster = Monster(fb.finishedBytes(), 0)
        let equipped_type = monster.GetEquippedType()
        @Expect(EnumMyGame_Sample_EquipmentValues(equipped_type), 2)
        let s = monster.GetEquippedAsShield().getOrThrow()
        @Expect(s.GetName(), "shield0")
        @Expect(s.GetWeight(), 10.0)
        @Expect(s.GetAux().getOrThrow().GetSize(), 7.7)
    }

    @TestCase
    func testUnionVector() {
        let monster = Monster(fb.finishedBytes(), 0)
        @Expect(monster.GetListSize(), 2)
        @Expect(EnumMyGame_Sample_EquipmentValues(monster.GetListType(UInt32(0))), 2)
        @Expect(EnumMyGame_Sample_EquipmentValues(monster.GetListType(UInt32(1))), 1)
        let s = monster.GetListAsShield(UInt32(0)).getOrThrow()
        @Expect(s.GetName(), "shield1")
        @Expect(s.GetWeight(), 20.0)
        @Expect(s.GetAux().getOrThrow().GetSize(), 8.8)
        let w = monster.GetListAsWeapon(UInt32(1)).getOrThrow()
        @Expect(w.GetName(), "weapon2")
        @Expect(w.GetDamage(), 7)
        @Expect(w.GetAux().getOrThrow().GetSize(), 12.56)
    }

    @TestCase
    func testStructVector() {
        let monster = Monster(fb.finishedBytes(), 0)
        let pathRead = monster.GetPath()
        @Expect(pathRead.size, 2)
        @Expect(pathRead[0].v0, 3)
        @Expect(pathRead[0].v1, false)
        @Expect(pathRead[0].v2, 6)
        @Expect(pathRead[0].v3, 3)
        @Expect(pathRead[0].v4, 2)
        @Expect(pathRead[0].v5, 4)
        @Expect(pathRead[0].v6, 5)
        @Expect(pathRead[0].v7, 6)
        @Expect(pathRead[0].v8, 7)
        @Expect(pathRead[0].v9, 6.28)
        @Expect(pathRead[0].v10, 6.28318)
        @Expect(pathRead[1].v0, 2)
        @Expect(pathRead[1].v1, false)
        @Expect(pathRead[1].v2, 4)
        @Expect(pathRead[1].v3, 3)
        @Expect(pathRead[1].v4, 1)
        @Expect(pathRead[1].v5, 4)
        @Expect(pathRead[1].v6, 5)
        @Expect(pathRead[1].v7, 6)
        @Expect(pathRead[1].v8, 7)
        @Expect(pathRead[1].v9, 3.14)
        @Expect(pathRead[1].v10, 3.14159)
    }
}