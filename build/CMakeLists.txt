# (C) Copyright 2017-2020 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

#
# MPAS/JEDI bundle
#

#
# Usage: cmake <mpas-bundle src dir> -DCMAKE_BUILD_TYPE=RelWithDebINfo -DCMAKE_VERBOSE_MAKEFILE=ON -DSNAPSHOT_DATE=2024-06-01 -DMPAS_DOUBLE_PRECISION=OFF

cmake_minimum_required( VERSION 3.14 )
project( mpas-bundle VERSION 3.0.0 LANGUAGES C CXX Fortran )

## ECBuild integration
include(GNUInstallDirs)
set( INSTALL_LIB_DIR ${CMAKE_INSTALL_LIBDIR} CACHE STRING "Library installation directory" FORCE ) #Force ecbuild to use the default platform lib install location
set( ECBUILD_DEFAULT_BUILD_TYPE Release CACHE STRING "ECBuild default build type" FORCE)
set( CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin )
set( CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib )
set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib )
find_package( ecbuild 3.5 REQUIRED HINTS ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/../ecbuild )
include( ecbuild_bundle )
ecbuild_bundle_initialize()
# Use external jedi-cmake or build in bundle

if(DEFINED ENV{jedi_cmake_ROOT})
  include( $ENV{jedi_cmake_ROOT}/share/jedicmake/Functions/git_functions.cmake )
  list( APPEND CMAKE_MODULE_PATH $ENV{jedi_cmake_ROOT}/share/jedicmake/Modules )
  message (INFO "CMAKE_MODULE_PATH")
else()
  ecbuild_bundle( PROJECT jedicmake GIT "https://github.com/JCSDA-internal/jedi-cmake.git" BRANCH develop UPDATE RECURSIVE )
  include( jedicmake/cmake/Functions/git_functions.cmake )
  list( APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/jedicmake/CMakeModules/Modules )
endif()

option(BUNDLE_SKIP_ECKIT "Don't build eckit" "ON" ) # Skip eckit build unless user passes -DBUNDLE_SKIP_ECKIT=OFF
option(BUNDLE_SKIP_FCKIT "Don't build fckit" "ON" ) # Skip eckit build unless user passes -DBUNDLE_SKIP_FCKIT=OFF
option(BUNDLE_SKIP_ATLAS "Don't build eckit" "ON" ) # Skip atlas build unless user passes -DBUNDLE_SKIP_ATLAS=OFF
ecbuild_bundle( PROJECT eckit     GIT "https://github.com/ecmwf/eckit.git" TAG 1.24.4 )
ecbuild_bundle( PROJECT fckit     GIT "https://github.com/ecmwf/fckit.git" TAG 0.11.0 )
ecbuild_bundle( PROJECT atlas     GIT "https://github.com/ecmwf/atlas.git" TAG 0.34.0 )

#TODO: When mpas-bundle becomes a public repo, consider changing the default value of BUNDLE_SKIP_ROPP-UFO to "ON"
option(BUNDLE_SKIP_ROPP-UFO "Don't build ROPP-UFO"  "OFF") # Build ropp-ufo unless user passes -DBUNDLE_SKIP_ROPP-UFO=ON
ecbuild_bundle( PROJECT ropp-ufo  GIT "https://github.com/JCSDA-internal/ropp-test.git"   TAG 96a0397 )
option(BUNDLE_SKIP_RTTOV "Don't build rttov"  "ON") # Skip rttov build unless user passes -DBUNDLE_SKIP_RTTOV=OFF
ecbuild_bundle( PROJECT rttov     GIT "https://github.com/JCSDA-internal/rttov.git"       BRANCH develop UPDATE )

ecbuild_bundle( PROJECT oops      GIT "https://github.com/JCSDA-internal/oops.git"        TAG d772173 )
ecbuild_bundle( PROJECT vader     GIT "https://github.com/JCSDA-internal/vader.git"       TAG 6d56a1e )
ecbuild_bundle( PROJECT saber     GIT "https://github.com/JCSDA-internal/saber.git"       TAG bba6f7e )
ecbuild_bundle( PROJECT crtm      GIT "https://github.com/JCSDA/CRTMv3.git"               TAG 73102a2 )

option(ENABLE_IODA_DATA "Obtain ioda test data from ioda-data repository (vs tarball)" ON)
ecbuild_bundle( PROJECT ioda-data GIT "https://github.com/JCSDA-internal/ioda-data.git"   TAG bcb0754 )
ecbuild_bundle( PROJECT ioda      GIT "https://github.com/JCSDA-internal/ioda.git"        TAG d49ed17 )
option(ENABLE_UFO_DATA "Obtain ufo test data from ufo-data repository (vs tarball)" ON)
ecbuild_bundle( PROJECT ufo-data  GIT "https://github.com/JCSDA-internal/ufo-data.git"    TAG 9e4eb40 )
ecbuild_bundle( PROJECT ufo       GIT "https://github.com/JCSDA-internal/ufo.git"         TAG 94d50d6 )


# Find external ESMF for mpas-model (optional)
find_package(ESMF 8.3.0 MODULE)

set(MPAS_DOUBLE_PRECISION "ON" CACHE STRING "MPAS-Model: Use double precision 64-bit Floating point.")
set(MPAS_CORES init_atmosphere atmosphere CACHE STRING "MPAS-Model: cores to build.")

ecbuild_bundle( PROJECT MPAS      GIT "https://github.com/MPAS-Dev/MPAS-Model" TAG v8.2.1 )
option(ENABLE_MPAS_JEDI_DATA "Obtain mpas-jedi test data from mpas-jedi-data repository (vs tarball)" ON)
ecbuild_bundle( PROJECT mpas-jedi-data  GIT "https://github.com/JCSDA-internal/mpas-jedi-data.git"  TAG 12cdc56 )
ecbuild_bundle( PROJECT mpas-jedi GIT "https://github.com/JCSDA-internal/mpas-jedi"      TAG 3.0.0.mmm )

# Set GIT_BRANCH_FUNC to MPAS-JEDI's current branch so that it can be used for mpas-jedi-data
find_branch_name(REPO_DIR_NAME mpas-jedi)

# If mpas-jedi's current branch is available in mpas-jedi-data repo, that branch will be checked out
branch_checkout (REPO_DIR_NAME mpas-jedi-data
                 BRANCH ${GIT_BRANCH_FUNC} )


ecbuild_bundle_finalize()
