#!/usr/bin/env python3

from datetime import datetime, timedelta
import sys

def main(dateIni, dateEnd, delta):
    datei = datetime.strptime(str(dateIni), "%Y%m%d%H")
    datef = datetime.strptime(str(dateEnd), "%Y%m%d%H")
    date  = datef

    while (date != datei):
      datestr  = date.strftime("%Y%m%d%H")
      print(datestr)
      date = date - timedelta(hours=int(delta))

if __name__ == '__main__': 
    dateIni = str(sys.argv[1])
    dateEnd = str(sys.argv[2])
    delta   = str(sys.argv[3])
    main(dateIni, dateEnd, delta)
