#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import shutil
import argparse
import subprocess


def untar_file(tar_file_path, extract_path):
    try:
        tar_cmd = ['tar', '-zxf', tar_file_path, '-C', extract_path]
        subprocess.run(tar_cmd, check=True)
    except Exception as e:
        print("tar error!")
        return


def clear_dir(old_dir):
    if os.path.exists(old_dir):
        shutil.rmtree(old_dir)


def move_dir(src_dir, dst_dir):
    shutil.copytree(src_dir, dst_dir)


def main():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--gen-dir', help='generate path of log', required=True)
    args_parser.add_argument('--source-dir', help='generate path of log', required=True)
    args = args_parser.parse_args()

    tar_file_path = os.path.join(args.source_dir, "v2.0.0.tar.gz")
    target_dir = os.path.join(args.gen_dir, "flatbuffers-2.0.0")

    clear_dir(os.path.join(args.source_dir, "include"))
    untar_file(tar_file_path, args.gen_dir)
    move_dir(os.path.join(target_dir, "include"), os.path.join(args.source_dir, "include"))


if __name__ == '__main__':
    sys.exit(main())
