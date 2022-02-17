#!/usr/bin/env python3

import argparse
from copy import deepcopy
import yaml

def getConfig():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('file', type=str,
                  help='yaml file to parse')
  ap.add_argument('key', type=str,
                  help='configuration address')

  args = ap.parse_args()

  key = args.key.split('.')

  with open(args.file) as file:

    config = yaml.load(file, Loader=yaml.FullLoader)


    a = deepcopy(config)
    for level in key:
      #print(a)
      #print(level)
      a = deepcopy(a[level])

    print(a)  

if __name__ == '__main__': getConfig()
