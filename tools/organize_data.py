'''
Organize ARO (airborne GNSS-RO) observation profile files into data-assimilation
synoptic-cycle subdirectories. For netcdf, also injects a 'record_number' variable
required by gnssaro_netcdf2ioda.py; bufr is left as-is (gnssaro_bufr2ioda.py assigns
its own sequenceNumber from file ordering).

Examples:
  # whole-directory / multi-cycle mode (original behavior): buckets every profile
  # file under dataDir into window-hourly cycle subdirectories spanning the files'
  # own dates
  python organize_data.py -dataD all_202301/ --format netcdf

  # single-cycle mode: only build the one cycle's subdirectory. Profiles within
  # [cycle-window/2, cycle+window/2) are kept for this cycle; the download step
  # (GetObs.csh) is responsible for fetching enough adjacent days/IOPs that no
  # profile inside this window gets missed. No overlap between cycles as long as
  # -w does not exceed the cycling interval.
  python organize_data.py -dataD aro_staging/ -d 2023010618 -w 6 --format bufr
'''
from datetime import datetime, timedelta
import numpy as np
import os, sys
import fnmatch
import argparse
import netCDF4


def convertJulianToDate(year, ddd):
  datein = datetime.strptime('{}-{}'.format(year, ddd), '%Y-%j').date()
  mm = datein.strftime('%m')
  dd = datein.strftime('%d')
  return mm+dd


def organizeCycle(sortedFiles, date, windowHR, cycleDir, format):
    print('Working on ', date.strftime("%Y%m%d%H"))
    os.system('mkdir -p '+cycleDir)
    # symmetric window: no overlap between adjacent cycles as long as windowHR
    # does not exceed the cycling interval
    prevDate = date - timedelta(hours=windowHR/2.)
    nextDate = date + timedelta(hours=windowHR/2.)

    nrec = 1
    for full_file_name in sortedFiles:
      file_name = full_file_name.split('/')[-1]

      # Get data from file name stamp
      sfil = file_name.split('_')[1].split('.')
      year = sfil[1]
      ddd = sfil[2]
      hh = sfil[3]
      mmdd = convertJulianToDate(year, ddd)
      DATE = year+mmdd+hh
      DATEdatetime = datetime.strptime(DATE, "%Y%m%d%H")

      if DATEdatetime >= prevDate and DATEdatetime < nextDate:
        os.system('cp -r '+ full_file_name +' '+ cycleDir)

        if format == 'netcdf':
          orgFile = cycleDir + '/' + file_name
          ncdf = netCDF4.Dataset(orgFile, 'r+', format='NETCDF4')
          MSL_alt = ncdf.variables['MSL_alt'].size
          recordN = np.array(np.repeat(nrec, MSL_alt), dtype=np.int64)

          ncdf.createVariable('record_number', 'i4', ('MSL_alt',), fill_value=-999)
          ncdf['record_number'][:] = recordN
          ncdf.close()
        # bufr: opaque binary format, just copy -- gnssaro_bufr2ioda.py assigns
        # sequenceNumber itself from file ordering
        nrec = nrec + 1


def main(dataDir, format='netcdf', targetDate=None, windowHR=6):

    if format == 'bufr':
        prefix = 'bfrPrf_'
        ext = '_bufr'
    else:
        prefix = 'atmPrf_'
        ext = '_nc'
    fname = prefix+'*'+ext

    obsoutfiles = []
    for files in os.listdir(dataDir):
      if fnmatch.fnmatch(files, fname):
        obsoutfiles.append(dataDir+'/'+files)

    sortedFiles = np.sort(obsoutfiles)

    if targetDate is not None:
        # single-cycle mode: only build the requested cycle
        date = datetime.strptime(str(targetDate), "%Y%m%d%H")
        cycleDir = dataDir + '/' + date.strftime("%Y%m%d%H")
        organizeCycle(sortedFiles, date, windowHR, cycleDir, format)
        return

    # whole-directory / multi-cycle mode (original behavior)
    year        = sortedFiles[0].split('/')[-1].split('_')[1].split('.')[1]
    dddFirst    = sortedFiles[0].split('/')[-1].split('_')[1].split('.')[2]
    dddLast     = sortedFiles[-1].split('/')[-1].split('_')[1].split('.')[2]

    mmddFirst = convertJulianToDate(year, dddFirst)
    mmddLast  = convertJulianToDate(year, dddLast)

    dateIni = year+mmddFirst+'00'
    dateFin = year+mmddLast+'18'

    datei = datetime.strptime(str(dateIni), "%Y%m%d%H")
    datef = datetime.strptime(str(dateFin), "%Y%m%d%H")

    date = datei
    while (date <= datef):
        cycleDir = dataDir + '/' + date.strftime("%Y%m%d%H")
        organizeCycle(sortedFiles, date, windowHR, cycleDir, format)
        date = date + timedelta(hours=windowHR)


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description=__doc__,
      formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument('-dataD', '--dataDir', type=str, required=True,
      help='Data directory')
  parser.add_argument('--format', type=str, default='netcdf', choices=['netcdf', 'bufr'],
      help='raw ARO file format to organize: netcdf (atmPrf_*_nc) or bufr (bfrPrf_*_bufr) '
           '(default: %(default)s)')
  parser.add_argument('-d', '--date', metavar='YYYYMMDDHH', type=str, default=None,
      help='process only this single cycle instead of the whole dataDir date range')
  parser.add_argument('-w', '--window', type=float, default=6,
      help='profiles within [cycle-window/2, cycle+window/2) are kept for this cycle '
           '(default: %(default)s). No overlap between cycles as long as this does '
           'not exceed the cycling interval.')
  args = parser.parse_args()
  main(args.dataDir, args.format, args.date, args.window)
