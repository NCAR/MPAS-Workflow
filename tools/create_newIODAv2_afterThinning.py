#!/usr/bin/env python3

import numpy as np
import os, sys
import fnmatch, time, joblib
import h5py as h5
import argparse
from joblib import Parallel, delayed
from os.path import exists as file_exists

def get_data_create_file(input_files, output_filename):
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

    print('Saving IODAv2 new observation file')
    outh5 = h5.File(output_filename, 'w')
    create_groups(outh5)
    create_metadata_dateTime_dataset(good_nlocs, good_dateTime, outh5)
    create_metadata_latitude_dataset(good_nlocs, good_lat, outh5)
    create_metadata_longitude_dataset(good_nlocs, good_lon, outh5)
    create_metadata_scan_position_dataset(good_nlocs, good_scan_position, outh5)
    create_metadata_sensor_azimuth_angle_dataset(good_nlocs, good_sensor_azimuth_angle, outh5)
    create_metadata_sensor_channel_dataset(nchans, sensor_channel, outh5)
    create_metadata_sensor_view_angle_dataset(good_nlocs, good_sensor_view_angle, outh5)
    create_metadata_sensor_zenith_angle_dataset(good_nlocs, good_sensor_zenith_angle, outh5)
    create_metadata_solar_azimuth_angle_dataset(good_nlocs, good_solar_azimuth_angle, outh5)
    create_metadata_solar_zenith_angle_dataset(good_nlocs, good_solar_zenith_angle, outh5)
    create_obserror_brightness_temperature_dataset(good_nlocs, nchans, rgood_obserror, outh5)
    create_obsvalue_brightness_temperature_dataset(good_nlocs, nchans, rgood_obsvalue_location, outh5)
    create_prepqc_brightness_temperature_dataset(good_nlocs, nchans, rgood_prepqc, outh5)
    create_varmetadata_wavenumber_dataset(nchans, varmetadata, outh5)
    create_nchans_dataset(nchans, outh5)
    create_nlocs_dataset(good_nlocs, outh5)
    create_nstring_dataset(good_nlocs, outh5)
    outh5.close()

def create_groups(output_dataset):
    """
    Creates the required groups in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    output_dataset.create_group('MetaData')
    output_dataset.create_group('ObsError')
    output_dataset.create_group('ObsValue')
    output_dataset.create_group('PreQC')
    output_dataset.create_group('VarMetaData')

# MetaData group
def create_metadata_dateTime_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/dateTime dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "dateTime": shape (nlocs,), type "<i8">
    output_dataset.create_dataset('MetaData/dateTime', (nlocs,), dtype='i8',
                                  fillvalue=-999)
    output_dataset['MetaData/dateTime'][:] = input_data
    
def create_metadata_latitude_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/latitude dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "latitude": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/latitude', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/latitude'][:] = input_data
    
def create_metadata_longitude_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/longitude dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "longitude": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/longitude', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/longitude'][:] = input_data    
    
def create_metadata_scan_position_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/scan_position dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "scan_position": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/scan_position', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/scan_position'][:] = input_data

def create_metadata_sensor_azimuth_angle_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/sensor_azimuth_angle dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "sensor_azimuth_angle": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/sensor_azimuth_angle', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/sensor_azimuth_angle'][:] = input_data

def create_metadata_sensor_channel_dataset(nchans, input_data, output_dataset):
    """
    Creates the MetaData/sensor_channel dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "sensor_channel": shape (nchans,), type "<i4">
    output_dataset.create_dataset('MetaData/sensor_channel', (nchans,), dtype='i4',
                                  fillvalue=-999)
    output_dataset['MetaData/sensor_channel'][:] = input_data


def create_metadata_sensor_view_angle_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/sensor_view_angle dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "sensor_view_angle": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/sensor_view_angle', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/sensor_view_angle'][:] = input_data

def create_metadata_sensor_zenith_angle_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/sensor_zenith_angle dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "sensor_zenith_angle": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/sensor_zenith_angle', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/sensor_zenith_angle'][:] = input_data

def create_metadata_solar_azimuth_angle_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/solar_azimuth_angle dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "solar_azimuth_angle": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/solar_azimuth_angle', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/solar_azimuth_angle'][:] = input_data

def create_metadata_solar_zenith_angle_dataset(nlocs, input_data, output_dataset):
    """
    Creates the MetaData/solar_zenith_angle dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "solar_zenith_angle": shape (nlocs,), type "<f4">
    output_dataset.create_dataset('MetaData/solar_zenith_angle', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['MetaData/solar_zenith_angle'][:] = input_data

# ObsError group
def create_obserror_brightness_temperature_dataset(nlocs, nchans, input_data, output_dataset):
    """
    Creates the ObsError/brightness_temperature dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "brightness_temperature": shape (nlocs, nchans), type "<f4">
    output_dataset.create_dataset('ObsError/brightness_temperature', (nlocs, nchans), dtype='f4',
                                  fillvalue=-999)
    output_dataset['ObsError/brightness_temperature'][:] = input_data

# ObsValue group
def create_obsvalue_brightness_temperature_dataset(nlocs, nchans, input_data, output_dataset):
    """
    Creates the ObsValue/brightness_temperature dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "brightness_temperature": shape (nlocs, nchans), type "<f4">
    output_dataset.create_dataset('ObsValue/brightness_temperature', (nlocs, nchans), dtype='f4',
                                  fillvalue=-999)
    output_dataset['ObsValue/brightness_temperature'][:] = input_data

# PreQC group
def create_prepqc_brightness_temperature_dataset(nlocs, nchans, input_data, output_dataset):
    """
    Creates the PreQC/brightness_temperature dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "brightness_temperature": shape (nlocs, nchans), type "<i4">
    output_dataset.create_dataset('PreQC/brightness_temperature', (nlocs, nchans), dtype='i4',
                                  fillvalue=-999)
    output_dataset['PreQC/brightness_temperature'][:] = input_data

# VarMetaData group
def create_varmetadata_wavenumber_dataset(nchans, input_data, output_dataset):
    """
    Creates the VarMetaData/sensor_band_central_radiation_wavenumber dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    #<HDF5 dataset "sensor_band_central_radiation_wavenumber": shape (nchans,), type "<f4">
    output_dataset.create_dataset('VarMetaData/sensor_band_central_radiation_wavenumber', (nchans,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['VarMetaData/sensor_band_central_radiation_wavenumber'][:] = input_data

# nchans dataset
def create_nchans_dataset(nchans, output_dataset):
    """
    Creates the nchans dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    data_array = np.arange(1, nchans + 1, 1, dtype='int32')
    #<HDF5 dataset "nchans": shape (nchans,), type "<i4">
    output_dataset.create_dataset('nchans', (nchans,), dtype='i4',
                                  fillvalue=-999)
    output_dataset['nchans'][:] = data_array

# nlocs dataset
def create_nlocs_dataset(nlocs, output_dataset):
    """
    Creates the nlocs dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    data_array = np.arange(1, nlocs + 1, 1, dtype='float32')
    #<HDF5 dataset "nlocs": shape (nlocs,), type ">f4">
    output_dataset.create_dataset('nlocs', (nlocs,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['nlocs'][:] = data_array

# nstring dataset
def create_nstring_dataset(nlocs, output_dataset):
    """
    Creates the nstring dataset in an output h5 dataset.
    output_dataset - A h5 Dataset object
    """
    nstring = 50
    data_array = np.arange(1, nstring + 1, 1, dtype='float32')
    #<HDF5 dataset "nstring": shape (nstring,), type ">f4">
    output_dataset.create_dataset('nstring', (nstring,), dtype='f4',
                                  fillvalue=-999)
    output_dataset['nstring'][:] = data_array

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

    output_filename = obsType+'_obs_'+DATE+ext
    get_data_create_file(obsoutfiles, output_filename)

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
  with joblib.parallel_backend(backend="threading"):
    parallel = Parallel(n_jobs=num_cores, verbose=50)
    print(parallel([delayed(main)(DATE, obsTypeIn[i], workDir) for i in range(len(obsTypeIn))]))
