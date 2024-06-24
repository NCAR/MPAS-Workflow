import os, sys
import getopt
from mpi4py import MPI
import numpy as np
import netCDF4 as nc4

from decimal import Decimal, getcontext

#============================================================================
class PyMPIConcatenateObserver():
  def __init__(self, debug=0, rundir=None, obsfile=None):
    self.debug = debug
    self.obsdir = rundir
    self.filename = obsfile

    self.format = 'NETCDF4'

    self.comm = MPI.COMM_WORLD
    self.rank = self.comm.Get_rank()
    self.size = self.comm.Get_size()

    self.set_nmem()

    self.set_maxeng()

    self.comm.Barrier()
    
    self.setup()

    self.LOGFILE = None


  def set_nmem(self):
    """
    Define the number of ensemble members
    """
    self.nmem = 0
    for mem_dir in os.listdir(self.obsdir):
      if mem_dir.startswith("mem") and (mem_dir != "mem000") :
        self.nmem += 1 

  def set_maxeng(self):
    """
    Define the number of numebr of engien vectors
    """
    self.maxeng = 0
    rootfile = '%s/mem001/%s' %(self.obsdir, self.filename)
    self.RFILE = nc4.Dataset(rootfile, 'r')
    igroups = self.RFILE.groups
    for grpname, group in igroups.items():
      if grpname.startswith("hofxm"):  
        self.maxeng += 1

  def setup(self):
    cnp = 0
    self.memlist = []
    for n in range(self.nmem):
      mem = n + 1
      if(cnp == self.rank):
        self.memlist.append(mem)
      cnp += 1
      if(cnp >= self.size):
        cnp = 0

#-----------------------------------------------------------------------------------------
  def copy_dimensions(self, ncin, ncout):
    self.diminfo = {}
    for name, dimension in ncin.dimensions.items():
      if(self.debug):
        self.LOGFILE.write('dimension: %s has size: %d\n' %(name, dimension.size))
      ncout.createDimension(name, dimension.size)

      self.diminfo[name] = dimension.size

      if(self.debug):
        self.LOGFILE.write('Create dimension: %s, no. dim: %d\n' %(name, len(dimension)))

   #add nchars dimension
   #ncout.createDimension('nchars', 5)

#-----------------------------------------------------------------------------------------
  def copy_attributes(self, ncin, ncout):
    inattrs = ncin.ncattrs()
    for attr in inattrs:
      if('_FillValue' != attr):
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

        if('stationIdentification' == varname):
          self.LOGFILE.write('\n\nHandle variable: %s\n' %(varname))
          self.LOGFILE.write('\tvariable dtype: %s\n' %(variable.dtype))
          self.LOGFILE.write('\tvariable size: %d\n' %(variable.size))
          self.LOGFILE.write('\tvariable datatype: %s\n' %(variable.datatype))
          self.LOGFILE.write('\tvariable dimensions: %s\n' %(variable.dimensions))
          self.LOGFILE.write('\tAvoid create string variable for now.\n')

          strdims = ('Location', 'Channel')

         #This did not work
         #strdims = (variable.dimensions, 'nchars')

         #This did not work
         #strdims = ()
         #for n in range(len(variable.dimensions)):
         #  dn = '%s' %(variable.dimensions[n])
         #  dt = (dn)
         #  strdims += dt
         #strdims += ('nchars')
         #newvar = outgroup.createVariable(varname, 'S1', strdims,
         #                                 fill_value=fill_value)
         #newvar._Encoding = 'ascii'

         #newvar = outgroup.createVariable(varname, variable.datatype, variable.dimensions,
         #                                 fill_value=fill_value)
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
    self.rootvarinfo = self.get_varinfo(self.RFILE)

    igroups = self.RFILE.groups

    self.grpinfo = []

    for grpname, group in igroups.items():
      self.grpinfo[grpname] = self.get_varinfo(group)

#-----------------------------------------------------------------------------------------
  def create_file(self):
    rootfile = '%s/mem000/%s' %(self.obsdir, self.filename)
    outputfile = '%s/%s' %(self.obsdir, self.filename)

    if(self.debug):
      self.LOGFILE.write('rootfile: %s\n' %(rootfile))
      self.LOGFILE.write('outputfile: %s\n' %(outputfile))

    if(0 == self.rank):
      if(os.path.exists(outputfile)):
        os.remove(outputfile)

    self.comm.Barrier()

    self.OFILE = nc4.Dataset(outputfile, 'w', format=self.format)

    self.RFILE = nc4.Dataset(rootfile, 'r')

    self.copy_dimensions(self.RFILE, self.OFILE)
    self.rootvardict = self.create_var_in_group(self.RFILE, self.OFILE)

    igroups = self.RFILE.groups

    self.outdict = {}
    self.comgrps = []
    self.memgrps = []
    self.modmemgrps = []
    self.hofx0dict = {}
    self.ombgvarlist = []
    self.obs_value = {}

    for n in range(self.nmem):
      mem = n + 1
      self.outdict[mem] = {}
    
    for grpname, group in igroups.items():

      if ('ObsValue' == grpname):
        self.comgrps.append(grpname)
        if (0 == self.rank):
          for name, variable in group.variables.items():
            val = self.read_var(name, variable)
            self.obs_value[name] = val
      else:
        self.comgrps.append(grpname)

    for grpname in self.comgrps:
      self.OFILE.createGroup(grpname)
   
    # Create hofx groups
    for n in range(self.nmem):
      mem = n + 1
      grpname = "hofx0_1"
      newname = self.get_newname(grpname, mem)
      ogroup = self.OFILE.createGroup(newname)
      self.memgrps.append(newname)
      # Create modulated groups
      for m in range(self.maxeng):
        neng = m + 1
        grpname = 'hofxm0_%d_1' %(neng)
        newname = self.get_newname(grpname, mem)
        self.OFILE.createGroup(newname)
        self.modmemgrps.append(newname)

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

    for n in range(self.nmem):
      mem = n + 1
      grpname = "hofx0_1"
      newname = self.get_newname(grpname, mem)
      ogroup = ogroups[newname]

      if(self.debug):
        self.LOGFILE.write('Create group: %s from: %s\n' %(newname, grpname))
        self.LOGFILE.flush()

      vardict = self.create_var_in_group(igroup, ogroup)

      if(mem in self.memlist):
        self.outdict[mem][newname] = vardict

      for m in range(self.maxeng):
        neng = m + 1
        grpname = 'hofxm0_%d_1' %(neng)
        newname = self.get_newname(grpname, mem)
        ogroup = ogroups[newname]
 
        vardict = self.create_var_in_group(igroup, ogroup)

        if(mem in self.memlist):
          self.outdict[mem][newname] = vardict

    # Create group of ombg and its varaibeles
    self.ombgdict = {}
    grpname = "ombg"
    self.OFILE.createGroup(grpname)
    ogroup = ogroups[grpname]
    vardict = self.create_var_in_group(igroup, ogroup)
    self.ombgdict[grpname] = vardict
    for name, variable in igroup.variables.items():
      self.ombgvarlist.append(name)

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

     #val = variable[:]
     #self.LOGFILE.write('\tvariable 0: %s\n' %(val[0]))
     #self.LOGFILE.flush()

    if(1 == dim):
      if('stationIdentification' == varname):
        if(self.debug):
          self.LOGFILE.write('\nskip write variable: %s\n' %(varname))
         #val = variable[:]
         #self.LOGFILE.write('\tval[0] = %s\n' %(val[0]))
       #strval = np.array(val, dtype='S5')
       #strval = np.array(val, dtype=object)
       #var[:] = strval 
      else:
        var[:] = variable[:]
    elif(2 == dim):
      var[:,:] = variable[:,:]
      if "amsua-cld" in self.filename:
          var[:,1] = variable.getncattr('_FillValue')
    elif(3 == dim):
      var[:,:,:] = variable[:,:,:]

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
  def mpi_average(self, varlist):
    meanvars = {}

    for varname in varlist:
      buf = None
      for mem in self.memlist:
        val = self.hofx0dict[mem][varname]
        if(self.debug):
          self.LOGFILE.write('use hofx0dict[%d][%s]\n' %(mem, varname))
        if(buf is None):
           buf = val
        else:
           buf += val

        tinfo = 'var %s mem %d' %(varname, mem)
        self.print_minmax(tinfo, val)
    
      self.comm.Allreduce(buf, val, op=MPI.SUM)
      val /= self.nmem
      meanvars[varname] = val

    return meanvars

#-----------------------------------------------------------------------------------------
  def print_minmax(self, name, val):
    if(self.debug):
      self.LOGFILE.write('\t%s max: %f, min: %f\n' %(name, np.max(val), np.min(val)))

#-----------------------------------------------------------------------------------------
  def process_ombg(self):
    self.LOGFILE.write('processing for ombg on rank: %d\n' %(self.rank))
    self.LOGFILE.flush()

    self.LOGFILE.write('get avearge ombg\n')
    meanvars = self.mpi_average(self.ombgvarlist)

    if(0 == self.rank):
      for varname in self.ombgvarlist:
        var = self.ombgdict['ombg'][varname]
        dim = len(var.dimensions)

        val = self.obs_value[varname] - meanvars[varname]

        if(1 == dim):
           var[:] = val
        elif(2 == dim):
           var[:,:] = val
        elif(3 == dim):
           var[:,:,:] = val

        self.print_minmax('ombg', val)

#-----------------------------------------------------------------------------------------
  def output_file(self):
    if(0 == self.rank):
      if(self.debug):
        self.LOGFILE.write('write root variables\n')
      self.write_var_in_group(self.RFILE, self.rootvardict)

      igroups = self.RFILE.groups
      for grpname in self.comgrps:
        if(self.debug):
          self.LOGFILE.write('write group: %s\n' %(grpname))
        group = igroups[grpname]
       #if('ombg' == grpname):
       #  continue
        self.write_var_in_group(group, self.comdict[grpname])

    if(self.debug):
      self.LOGFILE.flush()

    for mem in self.memlist:
      if(self.debug):
        self.LOGFILE.write('write for mem: %d\n' %(mem))
      infile = '%s/mem%3.3d/%s' %(self.obsdir, mem, self.filename)
      IFILE = nc4.Dataset(infile, 'r')
      if(self.debug):
        self.LOGFILE.write('input file: %s\n' %(infile))
        self.LOGFILE.flush()
      igroups = IFILE.groups

      grpname = 'hofx0_%d' %mem
      group = igroups[grpname]

      newname = self.get_newname(grpname, mem)
      vardict = self.outdict[mem][newname]
      self.write_var_in_group(group, vardict)

      self.hofx0dict[mem] = {}
      for name, variable in group.variables.items():
        self.hofx0dict[mem][name] = self.read_var(name, variable)

      if(self.debug):
        self.LOGFILE.write('write group %s from %s\n' %(newname, grpname))
        self.LOGFILE.flush()

      for n in range(self.maxeng):
        neng = n + 1
        grpname = 'hofxm0_%d_1' %(neng)
        newname = self.get_newname(grpname, mem)
        group = igroups[newname]
      
        if(self.debug):
          self.LOGFILE.write('write group %s from %s\n' %(newname, grpname))
          self.LOGFILE.flush()

        vardict = self.outdict[mem][newname]
        self.write_var_in_group(group, vardict)
 
      IFILE.close()

      if(self.debug):
        self.LOGFILE.flush()

#-----------------------------------------------------------------------------------------
  def process(self):

    if(self.LOGFILE is not None):
      self.LOGFILE.close()

    logflnm='log.%s.%4.4d' %(self.filename, self.rank)
    self.LOGFILE = open(logflnm, 'w')

    self.LOGFILE.write('size: %d\n' %(self.size))
    self.LOGFILE.write('rank: %d\n' %(self.rank))

    for mem in self.memlist:
      self.LOGFILE.write('mem: %d is on rank: %d\n' %(mem, self.rank))

    self.create_file()

    self.debug = 1
    self.output_file()

    self.process_ombg()

    self.RFILE.close()
    self.OFILE.close()

#=========================================================================================
if __name__== '__main__':
  debug = 0
  rundir = '.'
  obsfile = 'obsout_da_amsua_n19.h5'

 #--------------------------------------------------------------------------------
  opts, args = getopt.getopt(sys.argv[1:], '', ['debug=', 'rundir=', 'obsfile='])

  for o, a in opts:
    if o in ('--debug'):
      debug = int(a)
    elif o in ('--rundir'):
      rundir = a
    elif o in ('--obsfile'):
      obsfile = a
    else:
      print('o: <%s>' %(o))
      print('a: <%s>' %(a))
      assert False, 'unhandled option'

 #--------------------------------------------------------------------------------
  pmco = PyMPIConcatenateObserver(debug=debug, rundir=rundir, obsfile=obsfile)

  pmco.process()
