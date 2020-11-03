#!/usr/bin/env python3

import argparse

def memberStr():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('n', type=int,
                  help='Number of spaces')

  args = ap.parse_args()
  print(''.join([' ']*args.n))

if __name__ == '__main__': memberStr()
