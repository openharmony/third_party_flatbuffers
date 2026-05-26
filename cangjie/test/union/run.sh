#!/bin/bash

# Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
# This source file is part of the Cangjie project, licensed under Apache-2.0
# with Runtime Library Exception.
#
# See https://cangjie-lang.cn/pages/LICENSE for license information.

cp ../../*.cj ../

flatc --no-warnings --cangjie -o ./ ./union.fbs
flatc --no-warnings --cpp -o ./ ./union.fbs

find ../ -name '*.cj' -print0 | xargs -0 sed -i 's/package std.ast//g'

cjc ../*.cj ./*.cj -Woff unused --test

g++ ./main.cpp -I./ -I../../../include -o ./write_buffer

./write_buffer

./main

rm ../*.cj ./union_generated.cj ./union_generated.h ./*.cjo ./main ./test.buf ./write_buffer