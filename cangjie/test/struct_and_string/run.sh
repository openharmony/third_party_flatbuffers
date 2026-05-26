#!/bin/bash

# Copyright (c) Huawei Technologies Co., Ltd. 2026. All rights reserved.
# This source file is part of the Cangjie project, licensed under Apache-2.0
# with Runtime Library Exception.
#
# See https://cangjie-lang.cn/pages/LICENSE for license information.

cp ../../*.cj ../

flatc --no-warnings --cangjie -o ./ ./struct_and_string.fbs
flatc --no-warnings --cpp -o ./ ./struct_and_string.fbs

find ../ -name '*.cj' -print0 | xargs -0 sed -i 's/package std.ast//g'

cjc ../*.cj ./*.cj -Woff unused --test

g++ ./main.cpp -I./ -I../../../include -o ./write_buffer

./write_buffer

./main

rm ../*.cj ./struct_and_string_generated.cj ./struct_and_string_generated.h ./*.cjo ./main ./test.buf ./write_buffer