#!/usr/bin/env python3

import datetime as dt
import argparse

def advanceCYMDH():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('date', type=str,
                  help='Date in YYYYMMDDHH format')
  ap.add_argument('step', default=0, type=int, nargs = '?',
                  help='time step in hours')

  fmt = "%Y%m%d%H"
  args = ap.parse_args()
  date = dt.datetime.strptime(args.date,fmt)
  step = dt.timedelta(hours=args.step)
  print((date+step).strftime(fmt))

if __name__ == '__main__': advanceCYMDH()
