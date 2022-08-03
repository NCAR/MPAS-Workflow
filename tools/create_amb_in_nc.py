# create_amb_in_nc.py

import xarray as xr
import numpy as np
import datetime as dt
import argparse
from netCDF4 import Dataset, stringtoarr

def create_anal_incr_to_nc():
    """
    Create analysis increments (analysis-minus-background; amb) in netcdf.
    Usage: python create_amb_in_nc.py 2018041500 21600
           providing two input files as below.
              Input file1: an.2018-04-15_00.00.00.nc
              Input file2: bg.2018-04-15_00.00.00.nc
           => Output file: AmB.2018-04-14_21.00.00.nc
    """

    # Input arguments - Analysis time and the IAU time window in seconds
    #---------------------------------------------------------------------
    ap = argparse.ArgumentParser(description='Compute analysis increments')
    ap.add_argument('time', type=str,
                  help='xtime in YYYYMMDDHH format')
    ap.add_argument('IAU_window_length_s', default=21600, type=int, nargs = '?',
                  help='config_IAU_window_length_sin hours')
    args = ap.parse_args()
    print('====================================')
    print('create_amb_in_nc.py %s %s'%(args.time,args.IAU_window_length_s))
    print('====================================')

    # Time info
    #----------------------===------------------------
    tanl = dt.datetime.strptime(args.time,"%Y%m%d%H")
    delt = args.IAU_window_length_s / 3600. / 2.
    tiau = tanl - dt.timedelta(hours=delt)
    tstr = tiau.strftime('%Y-%m-%d_%H:%M:%S')
    print('Analysis time ',tanl)
    print('IAU begins at ',tiau)
    print('====================================')

    # Input and output files
    #-------------------------------------------------------
    file_a = 'an.%s.nc'%(tanl.strftime('%Y-%m-%d_%H.%M.%S'))	# Input analysis
    file_b = 'bg.%s.nc'%(tanl.strftime('%Y-%m-%d_%H.%M.%S'))	# Input background
    famb =  'AmB.%s.nc'%(tiau.strftime('%Y-%m-%d_%H.%M.%S')) 	# Output analysis increments
    fout  = Dataset(famb, 'w')

    # Read input files - chunks can be adjusted to fit into the memory, if files are too large.
    #------------------------------------------
    fa = Dataset(file_a) #xr.open_dataset(file_a,chunks='auto') # chuncks={"nVertLevels": 55})
    fb = Dataset(file_b) #xr.open_dataset(file_b,chunks='auto')

    # Output file - Global attributes and dimensions
    #------------------------------------------
    fout.description = "Analysis increments (Analysis-minus-Background; amb)"
    fout.input_analysis   = file_a
    fout.input_background = file_b
    fout.input_xtime = tanl.strftime('%Y-%m-%d_%H:%M:%S') + ' UTC'
    fout.IAU_window_length_s = args.IAU_window_length_s
    fout.input_interval = "initial_only"
    fout.io_type = "netcdf4"

    for name, dimension in fa.dimensions.items():
     if name == 'Time':
        fout.createDimension(name, None) 
     else:
        fout.createDimension(name, len(dimension))
    for atts in fa.ncattrs():
     if atts != "history":	# exclude the file history - we do not need it.
        fout.setncattr(atts, fa.getncattr(atts))

    # Variables for "tend_iau" in src/core_atmosphere/Registry.xml
    #--------------------------------------------------------------
    xvar = [ 'u', 'rho', 'theta', 'qv', 'qc', 'qr', 'qi', 'qs', 'qg' ]

    # Compute analysis increments (A-B)
    #----------------------------------------------
    for iv, name in enumerate(xvar):
        print(iv,name)
        # create a new variable (name, type, dimensions)
        dx = fout.createVariable(name+'_amb', fa[name].datatype, fa[name].dimensions)
        # copy variable attributes from fa
        dx.setncatts(fa[name].__dict__)
        attr = fa[name].getncattr('long_name') + ' analysis increment'
        #print(attr+' analysis increment')
        dx.setncatts({'long_name':attr})

        # fille values in the variable
        xa, xb = fa[name][:], fb[name][:]
        dx[:] = fa[name][:] - fb[name][:]
        print('A  :',np.min(xa),np.max(xa),np.mean(xa))
        print('B  :',np.min(xb),np.max(xb),np.mean(xb))
        print('AmB:',np.min(dx),np.max(dx),np.mean(dx))

    # Write time info
    tvar = 'xtime'
    xout = fout.createVariable(tvar, fa[tvar].datatype, fa[tvar].dimensions)
    xout.setncatts(fa[tvar].__dict__)
    tarr = stringtoarr(tstr, len(fa[tvar][0][:]))
    xout[0][:] = tarr

    fa.close()
    fb.close()
    fout.close()

    # Shift xtime in the output file for the IAU run (e.g., -3h)
    #-----------------------------------------------------------
    fn = Dataset(famb,'a')
    fn['xtime'][0] = tarr
    fn.close()

if __name__ == '__main__': create_anal_incr_to_nc()
