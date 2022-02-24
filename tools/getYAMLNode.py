#!/usr/bin/env python3

import argparse
from copy import deepcopy
import yaml

def getYAMLNode():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('default', type=str,
                  help='yaml file that holds default value')
  ap.add_argument('file', type=str,
                  help='yaml file to parse')
  ap.add_argument('key', type=str,
                  help='configuration address')

  ap.add_argument('-o','--outputType', type=str, default='v',
                  choices=['k', 'v', 'key', 'value'],
                  help='type of output, key or value')

  args = ap.parse_args()

  key = args.key.split('.')

  try:
    with open(args.file) as file:
      config = yaml.load(file, Loader=yaml.FullLoader)
      a = deepcopy(config)
      for level in key:
        a = deepcopy(a[level])
        l = level
  except:
    with open(args.default) as file:
      config = yaml.load(file, Loader=yaml.FullLoader)
      a = deepcopy(config)
      for level in key:
        a = deepcopy(a[level])
        l = level

  if args.outputType in ['v', 'value']:
    p = str(a)
    if isinstance(a, list):
      p = p.replace('\'','')
      p = p.replace('[','')
      p = p.replace(']','')
      p = p.replace(',',' ')
      p = ' '+p+' '
    print(p)
  elif args.outputType in ['k', 'key']:
    print(str(l))

if __name__ == '__main__': getYAMLNode()
