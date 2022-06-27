import os, sys
import h5py as h5

def main(obsFile):
    nc = h5.File(obsFile, 'r')
    nchans = nc['nchans'][:].tolist()
    if -999 in nchans:
      print('True')
        
if __name__ == '__main__': 
    obsFile = str(sys.argv[1])
    main(obsFile)
