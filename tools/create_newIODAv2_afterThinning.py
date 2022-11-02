#!/usr/bin/env python3

"""
Python code to ingest HDF5 data after an HofX application and write an HDF5 file
"""

import argparse
from datetime import datetime, timedelta
import glob
from pathlib import Path
import os.path
from os import getcwd
import sys, os

import numpy as np
import fnmatch, time, joblib
import h5py as h5
from netCDF4 import Dataset
from joblib import Parallel, delayed
from os.path import exists as file_exists

# globals
metopb_WMO_sat_ID = 3
metopa_WMO_sat_ID = 4
metopc_WMO_sat_ID = 5

def get_WMO_satellite_ID(obsType):
    if 'metop-a' in obsType:
        WMO_sat_ID = metopa_WMO_sat_ID
    elif 'metop-b' in obsType:
        WMO_sat_ID = metopa_WMO_sat_ID
    elif 'metop-c' in obsType:
        WMO_sat_ID = metopa_WMO_sat_ID
    else:
        WMO_sat_ID = -1
        print("could not determine satellite from obsType: %s" % obsType)
        sys.exit()

    return WMO_sat_ID

def init_obs_loc():
    obs = {
        ('brightness_temperature', "ObsValue"): [],
        ('brightness_temperature', "ObsError"): [],
        ('brightness_temperature', "PreQC"): [],
        ('satelliteId', 'MetaData'): [],
        ('channelNumber', 'MetaData'): [],
        ('latitude', 'MetaData'): [],
        ('longitude', 'MetaData'): [],
        ('dateTime', 'MetaData'): [],
        ('scan_position', 'MetaData'): [],
        ('solar_zenith_angle', 'MetaData'): [],
        ('solar_azimuth_angle', 'MetaData'): [],
        ('sensor_zenith_angle', 'MetaData'): [],
        ('sensor_view_angle', 'MetaData'): [],
        ('sensor_azimuth_angle', 'MetaData'): [],
        ('sensor_band_central_radiation_wavenumber', 'VarMetaData'): [],
        ('sensor_channel', 'MetaData'): [],
    }

    return obs

def get_good_obs_data(input_files, WMO_satellite_ID):
    """
    Get data from input files
    """
    # Build up arrays in loop over input_files
    dateTime               = np.asarray([])
    lat                    = np.asarray([])
    lon                    = np.asarray([])
    scan_position          = np.asarray([])
    sensor_azimuth_angle   = np.asarray([])
    sensor_view_angle      = np.asarray([])
    sensor_zenith_angle    = np.asarray([])
    solar_azimuth_angle    = np.asarray([])
    solar_zenith_angle     = np.asarray([])
    obserror               = np.asarray([])
    obsvalue               = np.asarray([])
    prepqc                 = np.asarray([])
    effectiveqc            = np.asarray([])

    good_dateTime             = np.asarray([])
    good_lat                  = np.asarray([])
    good_lon                  = np.asarray([])
    good_scan_position        = np.asarray([])
    good_sensor_azimuth_angle = np.asarray([])
    good_sensor_view_angle    = np.asarray([])
    good_sensor_zenith_angle  = np.asarray([])
    good_solar_azimuth_angle  = np.asarray([])
    good_solar_zenith_angle   = np.asarray([])
    good_obserror             = np.asarray([])
    good_prepqc               = np.asarray([])
    good_obsvalue_location    = np.asarray([])

    bad_locs_indices       = np.asarray([])

    print('Reading files and variables')
    for file_name in np.sort(input_files):
      # Read files from each processor
      h        = h5.File(file_name, 'r')
      # append variable values from each processor
      dateTime             = np.append( dateTime,             h['MetaData/dateTime'] )
      lat                  = np.append( lat,                  h['MetaData/latitude'] )
      lon                  = np.append( lon,                  h['MetaData/longitude'] )
      scan_position        = np.append( scan_position,        h['MetaData/scan_position'] )
      sensor_azimuth_angle = np.append( sensor_azimuth_angle, h['MetaData/sensor_azimuth_angle'] )
      sensor_view_angle    = np.append( sensor_view_angle,    h['MetaData/sensor_view_angle'] )
      sensor_zenith_angle  = np.append( sensor_zenith_angle,  h['MetaData/sensor_zenith_angle'] ) 
      solar_azimuth_angle  = np.append( solar_azimuth_angle,  h['MetaData/solar_azimuth_angle'] )
      solar_zenith_angle   = np.append( solar_zenith_angle,   h['MetaData/solar_zenith_angle'] )
      obserror             = np.append( obserror,             h['ObsError/brightness_temperature'][:,:] )
      prepqc               = np.append( prepqc,               h['PreQC/brightness_temperature'] )  
      effectiveqc          = np.append( effectiveqc,          h['EffectiveQC/brightness_temperature'][:,:] )
      obsvalue             = np.append( obsvalue,             h['ObsValue/brightness_temperature'][:,:] )

    nlocs          = len(lat)
    nchans         = h['nchans'].size
    sensor_channel = h['MetaData/sensor_channel']
    varmetadata    = h['VarMetaData/sensor_band_central_radiation_wavenumber']

    # Reshaping
    robserror    = obserror.reshape(nlocs, nchans)
    rprepqc      = prepqc.reshape(nlocs, nchans)
    reffectiveqc = effectiveqc.reshape(nlocs, nchans)
    robsvalue    = obsvalue.reshape(nlocs, nchans)

    # Get thinned locations (qcflag = 16) at channel 0 (iasi channel 16 (use_flag=1))
    bad_locs_indices = np.where(reffectiveqc[:,0] == 16)[0]

    # Get all variables at good locations
    print('Getting good locations')
    for j in range(nlocs):
      if not j in bad_locs_indices:
        good_dateTime             = np.append( good_dateTime, dateTime[j])
        good_lat                  = np.append( good_lat, lat[j] )
        good_lon                  = np.append( good_lon, lon[j] )
        good_scan_position        = np.append( good_scan_position, scan_position[j] )
        good_sensor_azimuth_angle = np.append( good_sensor_azimuth_angle, sensor_azimuth_angle[j] )
        good_sensor_view_angle    = np.append( good_sensor_view_angle, sensor_view_angle[j] )
        good_sensor_zenith_angle  = np.append( good_sensor_zenith_angle, sensor_zenith_angle[j] )
        good_solar_azimuth_angle  = np.append( good_solar_azimuth_angle, solar_azimuth_angle[j] )
        good_solar_zenith_angle   = np.append( good_solar_zenith_angle, solar_zenith_angle[j] )
        good_obserror             = np.append( good_obserror, robserror[j] )
        good_prepqc               = np.append( good_prepqc, rprepqc[j] )
        good_obsvalue_location    = np.append( good_obsvalue_location, robsvalue[j] )

    good_nlocs                 = len(good_lat)
    rgood_obsvalue_location    = good_obsvalue_location.reshape(good_nlocs, nchans)
    rgood_obserror             = good_obserror.reshape(good_nlocs, nchans)
    rgood_prepqc               = good_prepqc.reshape(good_nlocs, nchans)

    WMO_sat_ID = WMO_satellite_ID

    # Populate the obs_data dictionary
    obs_data = init_obs_loc()
    obs_data[('latitude', 'MetaData')] = np.array(good_lat, dtype='float32')
    obs_data[('longitude', 'MetaData')] = np.array(good_lon, dtype='float32')
    obs_data[('channelNumber', 'MetaData')] = np.array(h['nchans'][:], dtype='int32')
    obs_data[('scan_position', 'MetaData')] = np.array(good_scan_position[:], dtype='int32')
    obs_data[('solar_zenith_angle', 'MetaData')] = np.array(good_solar_zenith_angle[:], dtype='float32')
    obs_data[('solar_azimuth_angle', 'MetaData')] = np.array(good_solar_azimuth_angle[:], dtype='float32')
    obs_data[('sensor_zenith_angle', 'MetaData')] = np.array(good_sensor_zenith_angle[:], dtype='float32')
    obs_data[('sensor_azimuth_angle', 'MetaData')] = np.array(good_sensor_azimuth_angle[:], dtype='float32')
    obs_data[('sensor_view_angle', 'MetaData')] = np.array(good_sensor_view_angle[:], dtype='float32')
    obs_data[('sensor_band_central_radiation_wavenumber', 'VarMetaData')] = np.array(varmetadata[:], dtype='float32')
    obs_data[('sensor_channel', 'MetaData')] = np.array(sensor_channel, dtype='int32')
    obs_data[('satelliteId', 'MetaData')] = np.full((good_nlocs), WMO_sat_ID, dtype='int32')
    obs_data[('dateTime', 'MetaData')] = np.array(good_dateTime[:], dtype='int32')
    obs_data[('brightness_temperature', "ObsValue")] = np.array(rgood_obsvalue_location[:,:], dtype='float32')
    obs_data[('brightness_temperature', "ObsError")] = np.array(rgood_obserror[:,:], dtype='float32')
    obs_data[('brightness_temperature', "PreQC")] = np.array(rgood_prepqc[:,:], dtype='int32')

    return obs_data, good_nlocs

# Writing functions to create IODAv2 files
def create_groups(output_dataset):
    """
    Creates the required groups in an output netCDF4 dataset.
    output_dataset - A netCDF4 Dataset object
    """
    output_dataset.createGroup('MetaData')
    output_dataset.createGroup('ObsError')
    output_dataset.createGroup('ObsValue')
    output_dataset.createGroup('PreQC')
    output_dataset.createGroup('VarMetaData')

def create_root_group_attributes(output_dataset):
    """
    Creates several root group attributes in an output netCDF4 dataset.
    output_dataset - A netCDF4 Dataset object
    """
    output_dataset.setncattr('_ioda_layout', 'ObsGroup')
    output_dataset.setncattr('_ioda_layout_version', '0')

# nlocs dataset
def create_nlocs_dimension(good_nlocs, output_dataset):
    """
    Creates the nlocs dimension in an output netCDF4 dataset.
    output_dataset - A netCDF4 Dataset object
    """
    output_dataset.createDimension('nlocs', good_nlocs)
    output_dataset.createVariable('nlocs', 'i4', ('nlocs',), fill_value=-999)
    output_dataset.variables['nlocs'].setncattr('suggested_chunk_dim', good_nlocs)
    output_dataset.variables['nlocs'][:] = np.arange(1, good_nlocs + 1, 1, dtype='int32')
    
# nchans dataset
def create_nchans_dataset(obs_data, output_dataset):
    """
    Creates the nchans dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    nchans = len(obs_data[('channelNumber', 'MetaData')])
    output_dataset.createDimension('nchans', nchans)
    output_dataset.createVariable('nchans', 'i4', ('nchans',), fill_value=-999)
    output_dataset.variables['nchans'][:] = obs_data[('channelNumber', 'MetaData')]

# nstring dataset
def create_nstring_dataset(output_dataset):
    """
    Creates the nstring dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    nstring = 50
    data_array = np.arange(1, nstring + 1, 1, dtype='float32')
    output_dataset.createDimension('nstring', nstring)
    output_dataset.createVariable('nstring', 'f4', ('nstring',), fill_value=-999)
    output_dataset.variables['nstring'][:] = data_array

# MetaData group
def create_metadata_dateTime_dataset(obs_data, output_dataset):
    """
    Creates the ndatetime dimension in an output netCDF4 dataset.
    output_dataset - A netCDF4 Dataset object
    """
    output_dataset.createVariable('/MetaData/dateTime', 'i8', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/dateTime'][:] = obs_data[('dateTime', 'MetaData')]
    output_dataset['/MetaData/dateTime'].setncattr('units', 'seconds since 1970-01-01T00:00:00Z')

def create_metadata_latitude_variable(obs_data, output_dataset):
    """
    Creates the /MetaData/latitude variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/latitude', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/latitude'][:] = obs_data[('latitude', 'MetaData')]

def create_metadata_longitude_dataset(obs_data, output_dataset):
    """
    Creates the /MetaData/longitude variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/longitude', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/longitude'][:] = obs_data[('longitude', 'MetaData')]

def create_metadata_scan_position_dataset(obs_data, output_dataset):
    """
    Creates the /MetaData/scan_position variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/scan_position', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/scan_position'][:] = obs_data[('scan_position', 'MetaData')]

def create_metadata_sensor_azimuth_angle_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/sensor_azimuth_angle variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/sensor_azimuth_angle', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/sensor_azimuth_angle'][:] = obs_data[('sensor_azimuth_angle', 'MetaData')]

def create_metadata_sensor_channel_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/sensor_channel variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/sensor_channel', 'i4', ('nchans',), fill_value=-999)
    output_dataset['/MetaData/sensor_channel'][:] = obs_data[('sensor_channel', 'MetaData')] 

def create_metadata_sensor_view_angle_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/sensor_view_angle variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/sensor_view_angle', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/sensor_view_angle'][:] = obs_data[('sensor_view_angle', 'MetaData')]

def create_metadata_sensor_zenith_angle_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/sensor_zenith_angle variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/sensor_zenith_angle', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/sensor_zenith_angle'][:] = obs_data[('sensor_zenith_angle', 'MetaData')]

def create_metadata_solar_azimuth_angle_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/solar_azimuth_angle variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/solar_azimuth_angle', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/solar_azimuth_angle'][:] = obs_data[('solar_azimuth_angle', 'MetaData')]

def create_metadata_solar_zenith_angle_dataset(obs_data, output_dataset):
    """
    Creates the MetaData/solar_zenith_angle variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/MetaData/solar_zenith_angle', 'f4', ('nlocs',), fill_value=-999)
    output_dataset['/MetaData/solar_zenith_angle'][:] = obs_data[('solar_zenith_angle', 'MetaData')]

# ObsError group
def create_obserror_brightness_temperature_dataset(obs_data, output_dataset):
    """
    Creates the ObsError/brightness_temperature variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/ObsError/brightness_temperature', 'f4', ('nlocs','nchans',), fill_value=-999)
    output_dataset['/ObsError/brightness_temperature'][:] = obs_data[('brightness_temperature', "ObsError")]
    output_dataset['/ObsError/brightness_temperature'].setncattr('units', 'K')

# ObsValue group
def create_obsvalue_brightness_temperature_dataset(obs_data, output_dataset):
    """
    Creates the ObsValue/brightness_temperature variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/ObsValue/brightness_temperature', 'f4', ('nlocs','nchans',), fill_value=-999)
    output_dataset['/ObsValue/brightness_temperature'][:] = obs_data[('brightness_temperature', "ObsValue")]
    output_dataset['/ObsValue/brightness_temperature'].setncattr('units', 'K')

# PreQC group
def create_prepqc_brightness_temperature_dataset(obs_data, output_dataset):
    """
    Creates the PreQC/brightness_temperature variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/PreQC/brightness_temperature', 'f4', ('nlocs','nchans',), fill_value=-999)
    output_dataset['/PreQC/brightness_temperature'][:] = obs_data[('brightness_temperature', "PreQC")]
    output_dataset['/PreQC/brightness_temperature'].setncattr('units', 'K')

# VarMetaData group
def create_varmetadata_wavenumber_dataset(obs_data, output_dataset):
    """
    Creates the VarMetaData/sensor_band_central_radiation_wavenumber variable in an output netCDF4 dataset.
    output_dataset - A netCDF Dataset object
    """
    output_dataset.createVariable('/VarMetaData/sensor_band_central_radiation_wavenumber', 'f4', ('nchans',), fill_value=-999)
    output_dataset['/VarMetaData/sensor_band_central_radiation_wavenumber'][:] = obs_data[('sensor_band_central_radiation_wavenumber', 'VarMetaData')]

def writeIODA(good_nlocs, obs_data, output_file):
    """
    Creates the brightness temperature IODA data file.
    """
    output_dataset = Dataset(output_file, 'w')
    create_groups(output_dataset)
    create_root_group_attributes(output_dataset)
    create_nlocs_dimension(good_nlocs, output_dataset)
    create_nchans_dataset(obs_data, output_dataset)
    create_metadata_latitude_variable(obs_data, output_dataset)
    create_nstring_dataset(output_dataset)
    create_metadata_dateTime_dataset(obs_data, output_dataset)
    create_metadata_longitude_dataset(obs_data, output_dataset)
    create_metadata_scan_position_dataset(obs_data, output_dataset)
    create_metadata_sensor_azimuth_angle_dataset(obs_data, output_dataset)
    create_metadata_sensor_channel_dataset(obs_data, output_dataset)
    create_metadata_sensor_view_angle_dataset(obs_data, output_dataset)
    create_metadata_sensor_zenith_angle_dataset(obs_data, output_dataset)
    create_metadata_solar_azimuth_angle_dataset(obs_data, output_dataset)
    create_metadata_solar_zenith_angle_dataset(obs_data, output_dataset)
    create_obserror_brightness_temperature_dataset(obs_data, output_dataset)
    create_obsvalue_brightness_temperature_dataset(obs_data, output_dataset)
    create_prepqc_brightness_temperature_dataset(obs_data, output_dataset)
    create_varmetadata_wavenumber_dataset(obs_data, output_dataset)
    output_dataset.close()


def main(DATE, obsType, workDir):
    h0 = time.time()
    
    print('Starting '+__name__)

    diagprefix = 'obsout_hofx_'
    ext = '.h5'
    diagsuffix = obsType+'_*'+ext

    obsoutfiles = []
    for files in os.listdir(workDir):
      if fnmatch.fnmatch(files, diagprefix+diagsuffix):
        obsoutfiles.append(workDir+'/'+files)

    WMO_satellite_ID = get_WMO_satellite_ID(obsType)
    obs_data, good_nlocs = get_good_obs_data(obsoutfiles, WMO_satellite_ID)

    # Write HDF5 file
    print('Saving IODA new observation file')
    output_filename = obsType+'_obs_'+DATE+ext
    writeIODA(good_nlocs, obs_data, output_filename)

    hf = time.time()
    print('Time elapsed: ',hf  - h0)

    print('Finished '+__name__+' successfully')
        
if __name__ == '__main__': 

  parser = argparse.ArgumentParser()
  parser.add_argument('-d', '--datestr', type = str,
      help='Analysis date cycle')
  parser.add_argument('-o', '--obsType', type = str,
      help='Observation type')
  parser.add_argument('-w', '--workDir', type = str,
      help='Working directory')
  args = parser.parse_args() 

  DATE    =  args.datestr 
  obsType =  args.obsType.split(" ")
  workDir =  args.workDir

  obsTypeIn = []
  for obs in obsType:
    if file_exists(workDir+'/obsout_hofx_'+obs+'_0000.h5'):
      obsTypeIn.append(obs)

  num_cores = len(obsTypeIn)
  if num_cores == 0:
    print('No observation file available for this date')
    print('Finished '+__name__+' successfully')
    sys.exit()

  with joblib.parallel_backend(backend="threading"):
    parallel = Parallel(n_jobs=num_cores, verbose=50)
    print(parallel([delayed(main)(DATE, obsTypeIn[i], workDir) for i in range(len(obsTypeIn))]))
