# modules to cache xla files
from os.path import join
from os import getenv
from jax import config as jaxcfg
jaxcfg.update("jax_compilation_cache_dir", join(getenv("SCRATCH"), "tmp", "jax_cache"))
jaxcfg.update("jax_persistent_cache_min_entry_size_bytes", -1)
jaxcfg.update("jax_persistent_cache_min_compile_time_secs", 0)
jaxcfg.update("jax_persistent_cache_enable_xla_caches", "xla_gpu_per_fusion_autotune_cache_dir")
# modules to run graphcast
from pathlib import Path
from datetime import datetime
from earth2studio.data.mpas import MPASHybrid
from earth2studio.io import WPSBackend, NetCDF4Backend
from earth2studio.models.px import GraphCastOperational
from earth2studio.run import deterministic
# modules to parse command line arguments
from argparse import ArgumentParser

def get_cmd_line_args(argv=None):
  parser = ArgumentParser(
    description="Generate a 6h forecast or ensemble of forecasts using Graphcast")
  parser.add_argument("-cycle", "--cyclePointStr", help='Cycling point in format %%Y%%m%%d%%H')
  parser.add_argument("-fcdir", "--forecastBaseDir", help="Forecast base directory in workflow")
  parser.add_argument("-nmem", "--nMembers", type=int, help="Number of ensemble members")
  parser.add_argument("-pref", "--memberPrefix", default="mem", help="Member prefix in workflow")
  parser.add_argument("-inv", "--invariantFile", help="Name of invariant file")
  return vars(parser.parse_args(argv))  # returns dictionary instead of namespace

def load_graphcast_model():
  model = GraphCastOperational.load_model(GraphCastOperational.load_default_package())
  return model

def convert_to_datetime(cyclePointStr):
  return datetime.strptime(cyclePointStr, "%Y%m%d%H")

def get_file_paths(idxMember, cmdLineArgs):
  # obtain path elements
  forecastBaseDir = cmdLineArgs["forecastBaseDir"]
  cyclePointStr = cmdLineArgs["cyclePointStr"]
  if cmdLineArgs["nMembers"] > 1:  # forecast ensembles contain member subdirectory
    memberDir = cmdLineArgs["memberPrefix"] + str(idxMember).zfill(3)
  else:
    memberDir = ""  # empty string is omitted by join below
  forecastWorkDir = join(forecastBaseDir, cyclePointStr, memberDir)
  # assemble file names: earth2studio expects invariantFileWithPath
  # and outputPath to be of type Path
  invariantFileFullPath = Path(join(forecastWorkDir, cmdLineArgs["invariantFile"]))
  dataPathTemplate = join(forecastBaseDir, "%Y%m%d%H", memberDir, "mpasin.%Y-%m-%d_%H.%M.%S.nc")
  outputPath = Path(forecastWorkDir)
  return invariantFileFullPath, dataPathTemplate, outputPath


if __name__ == "__main__":
  # forecast settings
  cmdLineArgs = get_cmd_line_args()
  model = load_graphcast_model()
  pressureLevels = [50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000]
  cyclePointDatetime = convert_to_datetime(cmdLineArgs["cyclePointStr"])
  nSteps = 1

  # generate forecast for each member
  for idxMem in range(1, cmdLineArgs["nMembers"]+1):
    print(f"Generating forecast for member {idxMem}")
    invariantFile, dataPath, outputPath = get_file_paths(idxMem, cmdLineArgs)
    print(f"Data path: {dataPath}")
    mpasDatasrc = MPASHybrid(grid_path=invariantFile, data_path=dataPath, pressure_levels=pressureLevels)
    io = WPSBackend(outputPath, model_source=model.__class__.__name__)
    # io = NetCDF4Backend(join(outputPath, "gc_output.nc"), backend_kwargs={"mode": "w"})
    io = deterministic([cyclePointDatetime], nSteps, model, mpasDatasrc, io)
    io.close()
