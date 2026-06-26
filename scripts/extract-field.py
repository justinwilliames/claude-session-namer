#!/usr/bin/env python3
"""Read JSON from stdin and print a top-level field value. Usage: extract-field.py <field>"""
import sys, json

field = sys.argv[1]
try:
    data = json.load(sys.stdin)
    val = data.get(field, "")
    if val:
        print(val)
except Exception:
    pass
