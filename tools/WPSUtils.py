from enum import Enum
import fortran_io as f_io

class Projections( Enum ) :
  LATLON       = 0      # Cylindrical equidistant
  LC           = 1      # Lambert conformal
  PS           = 2      # Polar stereographic
  PS_WGS84     = 102
  MERC         = 3      # Mercator
  GAUSS        = 4      # Gaussian
  CYL          = 5
  CASSINI      = 6
  ALBERS_NAD83 = 105 
  ROTLL        = 203

class IntermediateFile( object ):
  def __init__( self, prefix, datestr ) :
    self.prefix_ = prefix
    self.datestr_ = datestr
    self.filename_ = self.prefix_.strip() + ":" + self.datestr_.strip()
    self.file_ = open( self.filename_, "wb" )

  def close( self ) :
    self.file_.close()

  def write_next_met_field( 
                            self,
                            version,
                            nx, ny,
                            iproj,
                            xfcst,
                            xlvl,
                            startlat, startlon, starti, startj,
                            deltalat, deltalon, dx, dy,
                            xlonc, truelat1, truelat2,
                            earth_radius, 
                            is_wind_grid_rel, 
                            field,
                            hdate,
                            units,
                            map_source,
                            desc,
                            slab
                            ) :

    f_io.unfmt_ftn_rec_write(
                              [ version ],
                              fmt=f_io.StructFormats.INT32,
                              file=self.file_
                            )

    if field == "GHT" :
      field = "HGT"
    
    if version == 5 :
      # FP check okay here?
      startloc = None
      if starti == 1.0 and startj == 1.0 :
        startloc = "SWCORNER"
      else :
        startloc = "CENTER  "

      f_io.unfmt_ftn_rec_write(
                                [
                                  hdate.ljust(24)[0:24],
                                  xfcst,
                                  map_source.ljust(32)[0:32],
                                  field.ljust(9)[0:9],
                                  units.ljust(25)[0:25],
                                  desc.ljust(46)[0:46],
                                  xlvl, nx, ny, iproj.value ],
                                fmt=( [ f_io.StructFormats.ARRCHAR ] +
                                      [ f_io.StructFormats.FP32 ] +
                                      [ f_io.StructFormats.ARRCHAR ] * 4 +
                                      [ f_io.StructFormats.FP32 ] +
                                      [ f_io.StructFormats.INT32 ] * 3 ),
                                file=self.file_
                                )
      if iproj == Projections.LATLON or iproj == Projections.GAUSS:
        f_io.unfmt_ftn_rec_write(
                                  [ 
                                    startloc.ljust(8)[0:8],
                                    startlat,
                                    startlon,
                                    deltalat,
                                    deltalon,
                                    earth_radius ],
                                  fmt=[ f_io.StructFormats.ARRCHAR ] + [ f_io.StructFormats.FP32 ] * 5,
                                  file=self.file_
                                )
      elif iproj == Projections.MERC :
        f_io.unfmt_ftn_rec_write(
                                  [ 
                                    startloc.ljust(8)[0:8],
                                    startlat,
                                    startlon,
                                    dx,
                                    dy,
                                    truelat1,
                                    earth_radius ],
                                  fmt=[ f_io.StructFormats.ARRCHAR ] + [ f_io.StructFormats.FP32 ] * 6,
                                  file=self.file_
                                )
      elif iproj == Projections.LC :
        f_io.unfmt_ftn_rec_write(
                                  [ 
                                    startloc.ljust(8)[0:8],
                                    startlat,
                                    startlon,
                                    dx,
                                    dy,
                                    xlonc,
                                    truelat1,
                                    truelat2,
                                    earth_radius ],
                                  fmt=[ f_io.StructFormats.ARRCHAR ] + [ f_io.StructFormats.FP32 ] * 8,
                                  file=self.file_
                                )
      elif iproj == Projections.PS :
        f_io.unfmt_ftn_rec_write(
                                  [ 
                                    startloc.ljust(8)[0:8],
                                    startlat,
                                    startlon,
                                    dx,
                                    dy,
                                    xlonc,
                                    truelat1,
                                    earth_radius ],
                                  fmt=[ f_io.StructFormats.ARRCHAR ] + [ f_io.StructFormats.FP32 ] * 7,
                                  file=self.file_
                                )

      f_io.unfmt_ftn_rec_write( [ is_wind_grid_rel ], fmt=f_io.StructFormats.INT32, file=self.file_ )
      f_io.unfmt_ftn_rec_write( slab,                 fmt=f_io.StructFormats.FP32, file=self.file_ )
      return 0
    else :
      print( "Didn't recognize format number " + str( version ) )
      return 1
