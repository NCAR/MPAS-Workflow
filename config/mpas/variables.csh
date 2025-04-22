#!/bin/csh -f

####################################
## workflow-relevant state variables
####################################
set MPASHydroIncrementVariables = ( \
  cloud_liquid_water \
  cloud_liquid_ice \
  graupel \
  rain_water \
  snow_water \
)

set MPASHydroStateVariables = ( \
  $MPASHydroIncrementVariables \
  cldfrac \
  re_cloud \
  re_snow \
  re_ice \
)

set StandardAnalysisVariables = ( \
  water_vapor_mixing_ratio_wrt_moist_air \
  air_pressure_at_surface \
  air_temperature \
  northward_wind \
  eastward_wind \
)
set StandardStateVariables = ( \
  $StandardAnalysisVariables \
  air_potential_temperature \
  dry_air_density \
  u \
  w \
  water_vapor_mixing_ratio_wrt_dry_air \
  air_pressure \
  landmask \
  seaice_fraction \
  snowc \
  skin_temperature_at_surface \
  ivgtyp \
  isltyp \
  snowh \
  vegetation_area_fraction \
  eastward_wind_at_10m \
  northward_wind_at_10m \
  air_temperature_at_2m \
  water_vapor_mixing_ratio_wrt_moist_air_at_2m \
  lai \
  smois \
  tslb \
  pressure_p \
)

set MPASJEDIVariablesFiles = (\
  geovars.yaml \
  obsop_name_map.yaml \
  keptvars.yaml \
)

set SACAStateVariables = ( \
  air_temperature \
  water_vapor_mixing_ratio_wrt_moist_air \
  air_potential_temperature \
  u \
  dry_air_density \
  water_vapor_mixing_ratio_wrt_dry_air \
  cloud_liquid_water \
  cloud_liquid_ice \
  snow_water \
  cloud_ice_number_concentration \
  cldfrac \
  xland \
  air_pressure \
  pressure_p \
  air_pressure_at_surface \
)
