#!/bin/tcsh -f

set yamls = (`ls ./*.yaml`)
foreach yaml ($yamls)
  echo $yaml
  ex -c ":%s@\(\ \+\)\(name:\ VertInterp\)@\1\2\r\1observation\ alias\ file:\ obsop_name_map\.yaml@" \
       +":%s@\(\ \+\)\(name:\ Identity\)@\1\2\r\1observation\ alias\ file:\ obsop_name_map\.yaml@" \
       +":wq" $yaml
end
sed -i 's&surface_altitude@GeoVaLs&GeoVaLs/surface_altitude&' *.yaml
sed -i 's&stationElevation@MetaData&MetaData/stationElevation&' *.yaml
