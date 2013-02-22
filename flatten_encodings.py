#!/usr/bin/python2
import json
import sys
obj = json.load(sys.stdin)

ICONV_MAP = {'ibm866': 'cp866',
             'x-mac-cyrillic': 'mac-cyrillic'}

for section in obj:
    print '#', section['heading']
    for encoding in section['encodings']:
        name = encoding['name']
        name = ICONV_MAP.get(name, name)
        for label in encoding['labels']:
            print name, label
