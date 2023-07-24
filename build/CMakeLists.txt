# (C) Copyright 2017-2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

#
# MPAS/JEDI bundle
#

cmake_minimum_required( VERSION 3.12 )
project( mpas-bundle VERSION 2.0.0 LANGUAGES C CXX Fortran )

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

ecbuild_bundle( PROJECT jedicmake GIT "https://github.com/JCSDA-internal/jedi-cmake.git" TAG afb8655 RECURSIVE )
include( jedicmake/cmake/Functions/git_functions.cmake )

option(BUNDLE_SKIP_ECKIT "Don't build eckit" "ON" ) # Skip eckit build unless user passes -DBUNDLE_SKIP_ECKIT=OFF
option(BUNDLE_SKIP_FCKIT "Don't build fckit" "ON" ) # Skip eckit build unless user passes -DBUNDLE_SKIP_FCKIT=OFF
option(BUNDLE_SKIP_ATLAS "Don't build atlas" "ON" ) # Skip atlas build unless user passes -DBUNDLE_SKIP_ATLAS=OFF
ecbuild_bundle( PROJECT eckit     GIT "https://github.com/ecmwf/eckit.git" TAG 1.18.2 )
ecbuild_bundle( PROJECT fckit     GIT "https://github.com/ecmwf/fckit.git" TAG 0.9.5 )
ecbuild_bundle( PROJECT atlas     GIT "https://github.com/ecmwf/atlas.git" TAG 0.29.0 )

#TODO: When mpas-bundle becomes a public repo, consider changing the default value of BUNDLE_SKIP_ROPP-UFO to "ON"
option(BUNDLE_SKIP_ROPP-UFO "Don't build ROPP-UFO"  "OFF") # Build ropp-ufo unless user passes -DBUNDLE_SKIP_ROPP-UFO=ON
ecbuild_bundle( PROJECT ropp-ufo  GIT "https://github.com/JCSDA-internal/ropp-test.git"   TAG 96a0397 )
option(BUNDLE_SKIP_RTTOV "Don't build rttov"  "OFF") # Skip rttov build unless user passes -DBUNDLE_SKIP_RTTOV=OFF
ecbuild_bundle( PROJECT rttov     GIT "https://github.com/JCSDA-internal/rttov.git"       TAG afa0890 )
ecbuild_bundle( PROJECT crtm      GIT "https://github.com/JCSDA-internal/crtm.git"        TAG e630e33 )
ecbuild_bundle( PROJECT oops      GIT "https://github.com/JCSDA-internal/oops.git"        TAG 5fca331 )
ecbuild_bundle( PROJECT saber     GIT "https://github.com/JCSDA-internal/saber.git"       TAG 1c35ddd )
ecbuild_bundle( PROJECT ioda      GIT "https://github.com/JCSDA-internal/ioda.git"        TAG 26e8a8e )
ecbuild_bundle( PROJECT ufo       GIT "https://github.com/JCSDA-internal/ufo.git"         TAG 5e3d981 )

# ioda and ufo test data
#---------------------------------

# If IODA branch is being built set GIT_BRANCH_FUNC to IODA's current branch.
# If a tagged version of IODA is being built set GIT_TAG_FUNC to ioda's current tag. In this case,
# IODA test files will be download from UCAR DASH and ioda-data repo will not be cloned.
# When LOCAL_PATH_JEDI_TESTFILES is set to the directory of IODA test files stored
# in a local directory, ioda-data repo will not be cloned

find_branch_name(REPO_DIR_NAME ioda)
# When LOCAL_PATH_JEDI_TESTFILES is set to the directory of IODA test files stored
# in a local directory, ioda-data repo will not be cloned
if( NOT DEFINED ENV{LOCAL_PATH_JEDI_TESTFILES} AND NOT DEFINED ${GIT_TAG_FUNC} )
  ecbuild_bundle( PROJECT ioda-data GIT "https://github.com/JCSDA-internal/ioda-data.git" TAG a95dc2a )
endif()

# If IODA's current branch is available in ioda-data repo, that branch will be checked out
branch_checkout (REPO_DIR_NAME ioda-data
                 BRANCH ${GIT_BRANCH_FUNC} )

# same procedure for ufo-data
find_branch_name(REPO_DIR_NAME ufo)
if( NOT DEFINED ENV{LOCAL_PATH_JEDI_TESTFILES} AND NOT DEFINED ${GIT_TAG_FUNC} )
  ecbuild_bundle( PROJECT ufo-data GIT "https://github.com/JCSDA-internal/ufo-data.git" TAG 6b9d571 )
endif()

# If UFO's current branch is available in ioda-data repo, that branch will be checked out
branch_checkout (REPO_DIR_NAME ufo-data
                 BRANCH ${GIT_BRANCH_FUNC})


set(MPAS_DOUBLE_PRECISION "OFF" CACHE STRING "MPAS-Model: Use double precision 64-bit Floating point.")
set(MPAS_CORES init_atmosphere atmosphere CACHE STRING "MPAS-Model: cores to build.")
ecbuild_bundle( PROJECT MPAS GIT "https://github.com/JCSDA-internal/MPAS-Model.git"  TAG jedi-2.0.0 )
ecbuild_bundle( PROJECT mpas-jedi GIT "https://github.com/JCSDA-internal/mpas-jedi"  TAG fbfe003 )

# same procedure for mpas-jedi-data
find_branch_name(REPO_DIR_NAME mpas-jedi)
if( NOT DEFINED ENV{LOCAL_PATH_JEDI_TESTFILES} AND NOT DEFINED ${GIT_TAG_FUNC} )
  ecbuild_bundle( PROJECT mpas-jedi-data GIT "https://github.com/JCSDA-internal/mpas-jedi-data.git" TAG 8b5ab19 )
endif()

# If mpas-jedi's current branch is available in mpas-jedi-data repo, that branch will be checked out
branch_checkout (REPO_DIR_NAME mpas-jedi-data
                 BRANCH ${GIT_BRANCH_FUNC} )


ecbuild_bundle_finalize()
