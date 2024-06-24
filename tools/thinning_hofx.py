import os, sys
import getopt
from mpi4py import MPI
import numpy as np
import netCDF4 as nc4

from decimal import Decimal, getcontext

#============================================================================
class PyMPIConcatenateObserver():
  def __init__(self, debug=0, thinning=0, rundir=None, hofxfile=None, outfile=None):
    self.debug = debug
    self.thinning = thinning
    self.obsdir = rundir
    self.hofxfile = hofxfile
    self.outfile = outfile

    self.format = 'NETCDF4'

    self.comm = MPI.COMM_WORLD
    self.rank = self.comm.Get_rank()
    self.size = self.comm.Get_size()

    self.comm.Barrier()
    
    #self.setup()

    self.LOGFILE = None

  def calc_dimensions(self, ncin, ncout):
    # Calculate how many locations are not thinned.
    igroups = ncin.groups
    for grpname, group in igroups.items():
      if(grpname == "EffectiveQC0"):
        variables = list(group.variables.items())
        varname, qc_var = variables[0]
        if len(qc_var.shape) == 2:
          self.valid_indices = np.where(np.any(qc_var[:, 0:] == 0, axis=1))[0]
        else:
          qc_var_2d = []
          for varname, qc_var in variables:
            qc_var = np.expand_dims(qc_var, axis=1)
            qc_var_2d.append((varname, qc_var))
          qc_var = np.concatenate([var[1] for var in qc_var_2d], axis=1)
          self.valid_indices = np.where(np.any(qc_var[:, 0:] == 0, axis=1))[0]

    # Determine number of thinned data
    self.new_locs = len(self.valid_indices)
    self.LOGFILE.write('thinned data has size: %d\n' %(self.new_locs))
   
    self.diminfo = {}
    for name, dimension in ncin.dimensions.items():
      if(self.debug):
        self.LOGFILE.write('dimension: %s has size: %d\n' %(name, dimension.size))

      if (name == "Location" and self.thinning == 1):
        self.old_locs = dimension.size
        self.diminfo[name] = self.new_locs
        ncout.createDimension(name, self.new_locs)
      else:
        self.diminfo[name] = dimension.size
        ncout.createDimension(name, dimension.size)

      if(self.debug):
        self.LOGFILE.write('Create dimension: %s, no. dim: %d\n' %(name, len(dimension)))

#-----------------------------------------------------------------------------------------
  def copy_attributes(self, ncin, ncout):
    inattrs = ncin.ncattrs()
    for attr in inattrs:
      if ('_FillValue' != attr):
        attr_value = ncin.getncattr(attr)
        if isinstance(attr_value, str):
          ncout.setncattr_string(attr, attr_value)
        else:
          ncout.setncattr(attr, attr_value)


#-----------------------------------------------------------------------------------------
  def get_newname(self, name, n):
    item = name.split('_')
    item[-1] = '%d' %(n)
    newname = '_'.join(item)
   #self.LOGFILE.write('No %d name: %s, newname: %s\n' %(n, name, newname))
    return newname

#-----------------------------------------------------------------------------------------
  def create_var_in_group(self, ingroup, outgroup):
    self.copy_attributes(ingroup, outgroup)

    fvname = '_FillValue'
    vardict = {}

   #create all var in group.
    for varname, variable in ingroup.variables.items():
      if(fvname in variable.__dict__):
        fill_value = variable.getncattr(fvname)
        if isinstance(fill_value, np.int32):
          fill_value = 999999999
        elif isinstance(fill_value, np.float32):
          fill_value = 999999999.0
        if('stationIdentification' == varname):
          self.LOGFILE.write('\n\nHandle variable: %s\n' %(varname))
          self.LOGFILE.write('\tvariable dtype: %s\n' %(variable.dtype))
          self.LOGFILE.write('\tvariable size: %d\n' %(variable.size))
          self.LOGFILE.write('\tvariable datatype: %s\n' %(variable.datatype))
          self.LOGFILE.write('\tvariable dimensions: %s\n' %(variable.dimensions))
          self.LOGFILE.write('\tAvoid create string variable for now.\n')

          strdims = ('Location', 'Channel')

          newvar = None
        else:
          newvar = outgroup.createVariable(varname, variable.datatype, variable.dimensions,
                                           fill_value=fill_value)
      else:
        newvar = outgroup.createVariable(varname, variable.datatype, variable.dimensions)

      self.copy_attributes(variable, newvar)

      if(self.debug):
        self.LOGFILE.write('\tcreate var: %s with %d dimension\n' %(varname, len(variable.dimensions)))

      vardict[varname] = newvar

    return vardict

#-----------------------------------------------------------------------------------------
  def get_varinfo(self, ingroup):
    varinfo = {}

   #create all var in group.
    for varname, variable in ingroup.variables.items():
      varinfo[varname] = variable

    return varinfo

#-----------------------------------------------------------------------------------------
  def read_var(self, name, variable):
    if(self.debug):
      self.LOGFILE.write('\tread var: %s with %d dimension\n' %(name, len(variable.dimensions)))
    if(1 == len(variable.dimensions)):
      val = variable[:]
    elif(2 == len(variable.dimensions)):
      val = variable[:,:]
    elif(3 == len(variable.dimensions)):
      val = variable[:,:,:]

    return val

#-----------------------------------------------------------------------------------------
  def get_fileinfo(self):
    self.rootvarinfo = self.get_varinfo(self.IFILE)

    igroups = self.IFILE.groups

    self.grpinfo = []

    for grpname, group in igroups.items():
      self.grpinfo[grpname] = self.get_varinfo(group)

#-----------------------------------------------------------------------------------------
  def create_file(self):
    hofxfile = '%s/%s' %(self.obsdir, self.hofxfile)
    outfile  = '%s/%s' %(self.obsdir, self.outfile)

    if(self.debug):
      self.LOGFILE.write('hofxfile: %s\n' %(hofxfile))
      self.LOGFILE.write('outfile: %s\n'  %(outfile))

    if(0 == self.rank):
      if(os.path.exists(outfile)):
        os.remove(outfile)

    self.comm.Barrier()

    self.OFILE = nc4.Dataset(outfile, 'w', format=self.format)

    self.IFILE = nc4.Dataset(hofxfile, 'r')

    self.calc_dimensions(self.IFILE, self.OFILE)

    self.rootvardict = self.create_var_in_group(self.IFILE, self.OFILE)

    igroups = self.IFILE.groups
  
    self.outdict = {}
    self.comgrps = []
    self.hofx0dict = {}
    
    for grpname, group in igroups.items():
      if (grpname == "MetaData" or grpname == "PreQC" or grpname == "ObsError" or grpname == "ObsValue" or grpname == "ObsType"):
        self.comgrps.append(grpname)

    for grpname in self.comgrps:
      self.OFILE.createGroup(grpname)
   
    # Save all gropu names for ogroups
    ogroups = self.OFILE.groups

    self.comdict = {}
    for grpname in self.comgrps:
      if(self.debug):
        self.LOGFILE.write('Create common group: %s\n' %(grpname))
        self.LOGFILE.flush()
      igroup = igroups[grpname]
      ogroup = ogroups[grpname]
      vardict = self.create_var_in_group(igroup, ogroup)
      if(0 == self.rank):
        self.comdict[grpname] = vardict

    if(self.debug):
      self.LOGFILE.flush()

#-----------------------------------------------------------------------------------------
  def write_var(self, var, dim, varname, ingroup):
    variable = ingroup.variables[varname]

    if(self.debug):
      self.LOGFILE.write('\n\nPrepare to write variable: %s\n' %(varname))
      self.LOGFILE.write('\tvariable dtype: %s\n' %(variable.dtype))
      self.LOGFILE.write('\tvariable size: %d\n' %(variable.size))
      self.LOGFILE.write('\tvariable dim: %d, %d\n' %(dim, len(variable.dimensions)))

    if (1 == dim and 'stationIdentification' == varname):
      if(self.debug):
        self.LOGFILE.write('\nskip write variable: %s\n' %(varname))
    else:
      self.write_var_reduce(var, variable)
      
    if(self.debug):
      self.LOGFILE.write('\nFinished write variable: %s\n' %(varname))
      self.LOGFILE.flush()

#-----------------------------------------------------------------------------------------
  def write_var_in_group(self, ingroup, vardict):
    if(self.debug):
      self.LOGFILE.flush()

   #write all var in group.
    for varname in vardict.keys():
      var = vardict[varname]
      if (varname == 'stationIdentification'):
        dim = 1
      else:
        dim = len(var.dimensions)
      if(self.debug):
        self.LOGFILE.write('\twrite variable: %s with dim: %d\n' %(varname, dim))
        self.LOGFILE.flush()

      self.write_var(var, dim, varname, ingroup)

    if(self.debug):
      self.LOGFILE.flush()

#-----------------------------------------------------------------------------------------
  def write_var_reduce(self, varin, varout):
    varin_length  = varin.shape[0]  if len(varin.shape)  >= 1 else 1
    varout_length = varout.shape[0] if len(varout.shape) >= 1 else 1
    
    if len(varin.shape) == 1:
      if (varin_length == self.new_locs and self.thinning == 1):
        varin[:varin_length] = varout[self.valid_indices]
      else:
        varin[:varin_length] = varout[:varin_length]

    elif len(varin.shape) == 2:
      if (varin.shape[0] == self.new_locs and self.thinning == 1):
        varin[:varin_length, :] = varout[self.valid_indices, :]
      else:
        varin[:varin_length, :] = varout[:varin_length, :]

    elif len(varin.shape) == 3:
      if (varin.shape[0] == self.new_locs and self.thinning == 1):
        varin[:varin_length, :, :] = varout[self.valid_indices, :, :]
      else:
        varin[:varin_length, :, :] = varout[:varin_length, :, :]

#-----------------------------------------------------------------------------------------
  def float_to_binary(self, float):
    getcontext().prec = 24
    d = Decimal(input)
    i = int(d * (1 << 23))
    return bin(i)

#-----------------------------------------------------------------------------------------
  def float2double(self, x):
    getcontext().prec = 16
    d = Decimal(x)
    return d(i)

#-----------------------------------------------------------------------------------------
  def output_file(self):
    if(0 == self.rank):
      if(self.debug):
        self.LOGFILE.write('write root variables\n')
      self.write_var_in_group(self.IFILE, self.rootvardict)

      igroups = self.IFILE.groups
      for grpname in self.comgrps:
        if(self.debug):
          self.LOGFILE.write('write group: %s\n' %(grpname))
          
        group = igroups[grpname]
        self.write_var_in_group(group, self.comdict[grpname])

    if(self.debug):
      self.LOGFILE.flush()

#-----------------------------------------------------------------------------------------
  def process(self):

    if(self.LOGFILE is not None):
      self.LOGFILE.close()

    logflnm='log.%s.%4.4d' %(self.hofxfile, self.rank)
    self.LOGFILE = open(logflnm, 'w')

    self.LOGFILE.write('size: %d\n' %(self.size))
    self.LOGFILE.write('rank: %d\n' %(self.rank))

    self.create_file()

    self.debug = 1
    self.output_file()

    self.IFILE.close()
    self.OFILE.close()

#=========================================================================================
if __name__== '__main__':
  debug = 0
  rundir = '.'
  hofxfile = 'obsout_da_amsua_n19.h5'
  outfile = 'new_obsout_da_amsua_n19.h5'
 #--------------------------------------------------------------------------------
  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=','thinning=', 'rundir=', 'hofxfile=', 'outfile='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--thinning'):
      thinning = int(a)
    elif o in ('--rundir'):
      rundir = a
    elif o in ('--hofxfile'):
      hofxfile = a
    elif o in ('--outfile'):
      outfile = a
    else:
      print('o: <%s>' %(o))
      print('a: <%s>' %(a))
      assert False, 'unhandled option'

 #--------------------------------------------------------------------------------
  pmco = PyMPIConcatenateObserver(debug=debug, thinning=thinning, rundir=rundir, hofxfile=hofxfile, outfile=outfile)

  pmco.process()
