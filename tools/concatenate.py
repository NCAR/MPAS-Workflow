import h5py as h5
import dask.array as da
import time
import glob, os, sys
import numpy as np
import netCDF4
import argparse
import logging

logging.basicConfig(filename='log.concatenate', filemode='w', format='%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S', level=logging.DEBUG)

IODAfloat_missing_value = float(-3.3687953e+38)
YDIAGfloat_missing_value = float(9.969209968386869e+36)


def from_h5(fn,var):
    try:
      return h5.File(fn, 'r')[var]
    except OSError as error:
      logging.warning(error)
      pass


def create_nc_all(variables,dimensions,data,nlocs,file_name):
    ftype = 'f4'
    ncdf = netCDF4.Dataset(file_name,'w', format='NETCDF4')
    ncdf.createDimension('nlocs', nlocs)

    for dim,varname in zip(dimensions,variables):
      ncdf.createDimension(dim.name, dim.size)
      ncdf.createVariable(varname, ftype, ('nlocs',dim.name), fill_value=IODAfloat_missing_value)
      ncdf[varname][:] = data[varname]
    ncdf.close()


def main(app,diagnostic_dir,prefix):
    st = time.time()

    # Determine obsSpace suffix
    file_0000 = prefix+'_'+args.app+'_*_0000.nc4'
    files = np.sort(glob.glob(diagnostic_dir + '/'+  file_0000, recursive=True))

    ncfiles = []
    s = '_'
    suffix_s = [s.join(fi.split('/')[-1].split('_')[2:-1]) if len(fi.split('/')[-1].split('_')[2:-1]) > 1 else fi.split('/')[-1].split('_')[2:-1] for fi in files]

    for suffix in suffix_s:
      logging.info('Working on: '+ prefix+ ' '+ suffix)
      filename = prefix+'_'+app+'_'+suffix+'_*.nc4'

      files = np.sort(glob.glob(diagnostic_dir + '/'+ filename, recursive=True))
      nfiles = len(files)

      variables = list(netCDF4.Dataset(files[0],'r').variables.keys())
      dimensions = list(netCDF4.Dataset(files[0],'r').dimensions.values())[1:] # remove nlocs

      data_dict = {}
      missing_val = YDIAGfloat_missing_value if prefix == 'ydiags' else IODAfloat_missing_value

      for v in variables:
        var = da.concatenate([da.ma.masked_equal(da.from_array(from_h5(files[ind],v), chunks="auto"), missing_val) for ind in range(nfiles)])
        data_dict.update({v: var})

      nlocs = data_dict[variables[0]].shape[0]

      output_file_name = diagnostic_dir + '/'+ prefix+'_'+app+'_'+suffix+'.nc4'
      try:
        os.remove(output_file_name)
      except OSError:
        pass
      create_nc_all(variables,dimensions,data_dict,nlocs,output_file_name)
      ncfiles.append(os.path.isfile(output_file_name))

    return ncfiles


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Concatenate JEDI application diagnostics from GOMsaver and YDIAGsaver filters', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('app', type=str, help='JEDI application category (e.g., da or hofx)')
    parser.add_argument('obsFeedbackDir', type=str, help='Observation feedback files directory')
    args = parser.parse_args()

    diagTypes = ['geoval','ydiags']
    for prefix in diagTypes:
      ncfiles = main(args.app, args.obsFeedbackDir, prefix)

    if all(ncfiles):
      logging.info('Finished '+__name__+' successfully')
    else:
      logging.error('Concatenated files were not created, exiting')
