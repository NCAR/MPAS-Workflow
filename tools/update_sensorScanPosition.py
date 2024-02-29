#!/usr/bin/env python
import netCDF4
import os
import shutil
from fix_float2int import main as float2int

#This script is contributed by Fabio Diniz at JCSDA.
fname = os.getenv('fname', 'please set obsName')

with netCDF4.Dataset(fname) as ds:
    if ds['/MetaData/sensorScanPosition'].dtype != 'int32':
        print('found file ..dtype not int32', fname )
        found = True
    else: 
        print('already updated',fname)
        found = False
if found:
    fname_modified = f'{fname}.modified'
    if os.path.exists(fname_modified):
        print('fname_modified exist=',fname_modified)
        os.remove(fname_modified)
    shutil.copyfile(fname, fname_modified)

    float2int(fname_modified, '/MetaData/sensorScanPosition')
    os.remove(fname)  #remove the file with float sensorScanPosition
