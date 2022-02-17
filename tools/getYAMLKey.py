#!/usr/bin/env python3

import argparse
from copy import deepcopy
import re
import yaml

def getConfig():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('default', type=str,
                  help='yaml file that holds default value')
  ap.add_argument('file', type=str,
                  help='yaml file to parse')
  ap.add_argument('key', type=str,
                  help='configuration address')

  args = ap.parse_args()

  key = args.key.split('.')

  try:
    with open(args.file) as file:
      config = yaml.load(file, Loader=yaml.FullLoader)
      a = deepcopy(config)
      for level in key:
        a = deepcopy(a[level])
  except:
    with open(args.default) as file:
      config = yaml.load(file, Loader=yaml.FullLoader)
      a = deepcopy(config)
      for level in key:
        a = deepcopy(a[level])

  p = str(a)
  if isinstance(a, list):
    p = p.replace('\'','')
    p = p.replace('[','')
    p = p.replace(']','')
    p = p.replace(',',' ')
  print(p)

if __name__ == '__main__': getConfig()
