#!/usr/bin/env python3
# Change time format from YYYYMMDDHH to YYYY-mm-dd_HH (by default) 
# or from YYYY-MM-DD_HH:00:00 to YYYYMMDD (with 1 as the second argument)

import datetime as dt
import argparse

def TimeFmtChange():

  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('date', type=str,
                  help='Date in YYYYMMDDHH format')
  ap.add_argument('fmt', default=0, type=int, nargs = '?')
  # 0:YYYYMMDDHH => YYYY-mm-dd_HH, 1:YYYY-MM-DD_HH:00:00 => YYYYMMDD

  args = ap.parse_args()
  if args.fmt == 0:
     fmt_in = "%Y%m%d%H"
     fmt_out = "%Y-%m-%d_%H" #:00:00" 
  if args.fmt == 1:
     fmt_in = "%Y-%m-%d_%H:00:00" 
     fmt_out = "%Y%m%d%H"
  date = dt.datetime.strptime(args.date,fmt_in)
  print(date.strftime(fmt_out))

if __name__ == '__main__': TimeFmtChange()
