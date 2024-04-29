from datetime import datetime, timedelta
import sys

def getFCMeanTimes(meantimes,delta):
  if meantimes == None:
    datestr = None
  else:
    times = meantimes.split('T')[1]
    dtimes = datetime.strptime(str(times), "%H")
    datep = dtimes - timedelta(hours=int(delta))
    datestr   = 'T'+datep.strftime("%H")
  return datestr
