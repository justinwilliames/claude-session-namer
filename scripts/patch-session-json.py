#!/usr/bin/env python3
"""Atomically patch title + titleSource in a Claude Code session JSON file."""
import json, sys, os, tempfile

path = sys.argv[1]
title = sys.argv[2]

with open(path) as f:
    data = json.load(f)

data['title'] = title
data['titleSource'] = 'user'

dir_ = os.path.dirname(path)
with tempfile.NamedTemporaryFile('w', dir=dir_, delete=False, suffix='.tmp') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

os.replace(tmp_path, path)
