#!/usr/bin/python3

import sys
import configparser

SETTING=sys.argv[1]
VALUE=sys.argv[2]
PATHCONFFILE=sys.argv[3]

config = configparser.ConfigParser(comment_prefixes='/', allow_no_value=True)
config.optionxform = str
config.read(PATHCONFFILE)
config.set('CONFIG', SETTING, VALUE)
with open(PATHCONFFILE, 'w') as configfile:
    config.write(configfile, space_around_delimiters=False)