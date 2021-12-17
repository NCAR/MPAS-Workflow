import argparse
from copy import deepcopy
import datetime as dt
import netCDF4 as nc
import os

def updateXTIME():

  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('filename', type=str,
                  help='netcdf file to modify')
  ap.add_argument('date', type=str,
                  help='Date in YYYYMMDDHH format')
  args = ap.parse_args()

  assert os.path.exists(args.filename), 'filename must exist!'
  ncfile = nc.Dataset(args.filename, 'a')

  # copy global attributes all at once via dictionary
  atts = deepcopy(ncfile.__dict__)

  d = dt.datetime.strptime(args.date, '%Y%m%d%H')
  confdate = d.strftime('%Y-%m-%d_%H:%M:%S')
  atts['config_start_time'] = confdate
  atts['config_stop_time'] = confdate
  ncfile.setncatts(atts)

  varname = 'xtime'
  xtime_ = ncfile[varname][0][:]
  xtime = nc.stringtoarr(confdate, len(ncfile[varname][0][:]))
  ncfile[varname][0] = xtime

  ncfile.close()

if __name__ == '__main__': updateXTIME()
