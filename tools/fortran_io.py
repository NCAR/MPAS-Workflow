from collections.abc import Iterable
import struct
from enum import Enum
from typing import Union
from io import TextIOWrapper
import numpy as np

################################################################################
#
# Wrapper classes around struct formatting options just to constrain inputs
#
class StructFormats( Enum ) :
  #             # C Type                  Python Type             Standard size in bytes (note)
  NULL    = "x" # pad byte                no value                  (7)
  CHAR    = "c" # char                    bytes of length 1       1 
  SCHAR   = "b" # signed char             integer                 1 (1), (2)
  UCHAR   = "B" # unsigned char           integer                 1 (2)
  BOOL    = "?" # _Bool                   bool                    1 (1)
  INT16   = "h" # short                   integer                 2 (2)
  UINT16  = "H" # unsigned short          integer                 2 (2)
  INT32   = "i" # int                     integer                 4 (2)
  UINT32  = "I" # unsigned int            integer                 4 (2)
  #       = "l" # long                    integer                 4 (2)
  #       = "L" # unsigned long           integer                 4 (2)
  INT64   = "q" # long long               integer                 8 (2)
  UINT64  = "Q" # unsigned long long      integer                 8 (2)
  #       = "n" # ssize_t                 integer                   (3)
  #       = "N" # size_t                  integer                   (3)
  FP16    = "e" # *IEEE754 half float(6)  float                   2 (4)
  FP32    = "f" # float                   float                   4 (4)
  FP64    = "d" # double                  float                   8 (4)
  ARRCHAR = "s" # char[]                  bytes                     (9)
  PCHAR   = "p" # char[]                  bytes                     (8)
  #       = "P" # void*                   integer                   (5)
  # Notes : refer to https://docs.python.org/3/library/struct.html#format-characters

  def to_dtype( self ) :
    if "INT" in self.name or "FP" in self.name :
      return self.name[0].lower() + str(int(int(self.name[len(self.name.rstrip( "0123456789" )):]) / 8))

class StructEndian( Enum ) :
  BIG    = ">"
  LITTLE = "<"


def calcsize( data : Iterable, fmt : Union[StructFormats, Iterable[StructFormats]] ) :
  """Calcuclates size of iterable data using format
  data - iterable of primitive data (including str)
  fmt  - a single StructFormat to use on all data elements or iterable index matched to each data element
  """
  sizeBytes = 0
  isIter = isinstance( fmt, Iterable )
  ithFmt = None

  if isIter :
    if len( fmt ) != len( data ) :
      raise Exception( "Mismatch size of struct format and data" )
  else :
    ithFmt = fmt.value

  if ithFmt == StructFormats.ARRCHAR.value or ithFmt == StructFormats.PCHAR.value or isIter :
    for i, elem in enumerate( data ) :
      if isIter :
        ithFmt = fmt[i].value

      count = ""
      if ithFmt == StructFormats.ARRCHAR.value or ithFmt == StructFormats.PCHAR.value :
        count = str( len( elem ) )

      sizeBytes += struct.calcsize( count + ithFmt )
  else :
    # we know they are all the same
    totalElems = len( data )
    if isinstance( data, np.ndarray ) :
      totalElems = data.size
    sizeBytes += struct.calcsize( ithFmt ) * totalElems

  return sizeBytes




def unfmt_ftn_rec_write( 
                        data     : Iterable,
                        filename : str = None,
                        file     : TextIOWrapper = None,
                        endian   : StructEndian = StructEndian.BIG,
                        fmt      : Union[StructFormats, Iterable[StructFormats]] = StructFormats.INT32,
                        append   : bool = True 
                        ) :
  """Writes out a Fortran unformatted record using byte amount record labels
  filename - file to write to if provided
  file     - file handle to write to if provided
  data     - iterable of primitive data (including str)
  endian   - endianness of data and record label
  fmt      - a single StructFormats to use on all data elements or iterable index matched to each data element
  append   - append to file or overwrite existing data
  """
  if filename is not None :
    file = open( filename, ( "a" if append else "w" ) + "b" )
  elif file is None :
    print( "Error : No filename or file handle provided!" )
    return 1

  sizeBytes = calcsize( data, fmt )
  file.write( struct.pack( endian.value + StructFormats.UINT32.value, sizeBytes ) )
  isIter = isinstance( fmt, Iterable )
  ithFmt = None

  if not isIter :
    ithFmt = fmt.value

  if ithFmt == StructFormats.ARRCHAR.value or ithFmt == StructFormats.PCHAR.value or isIter :
    for i, elem in enumerate( data ) :
      if isIter :
        ithFmt = fmt[i].value

      if isinstance( elem, str ) :
        file.write( struct.pack( endian.value + str( len( elem ) ) + ithFmt, elem.encode( 'utf-8' ) ) )
      else :
        file.write( struct.pack( endian.value + ithFmt, elem ) )
  else :
    # we know they are all the same
    if isinstance( data, np.ndarray ) :
      file.write( np.asfortranarray( data, dtype=endian.value + fmt.to_dtype() ).tobytes() )
    else :
      baseStruct = struct.Struct( endian.value + str( len( data ) ) + ithFmt )
      file.write( baseStruct.pack( *data ) )
    

  file.write( struct.pack( endian.value + StructFormats.UINT32.value, sizeBytes ) )

  if filename is not None :
    file.close()
  return 0


