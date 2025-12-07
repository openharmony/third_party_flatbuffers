#!/bin/bash

# Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
# This source file is part of the Cangjie project, licensed under Apache-2.0
# with Runtime Library Exception.
#
# See https://cangjie-lang.cn/pages/LICENSE for license information.

cp ../*.cj ./

flatc --no-warnings --cangjie -o ./ ./monster.fbs

find . -name '*.cj' -print0 | xargs -0 sed -i 's/package std.ast//g'

cjc ./*.cj ./all/main.cj -Woff unused --test

./main

rm ./*.cj ./*.cjo ./main