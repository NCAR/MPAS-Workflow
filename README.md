
MPAS-Workflow
=============
 
A tool for cycling forecast and data assimilation experiments with the MPAS-Atmosphere model and the
MPAS-JEDI data assimilation package.

Starting a cycling experiment on the Cheyenne HPC
-------------------------------------------------

```
 #login to Cheyenne

 mkdir -p /fresh/path/for/submitting/experiments

 cd /fresh/path/for/submitting/experiments

 module load git

 git clone https://github.com/NCAR/MPAS-Workflow

 #modify configuration as needed in scenarios/ and config/

 source env-setup/cheyenne.csh
 #OR
 source env-setup/cheyenne.sh

 ./drive.csh
 #OR
 ./run.csh {{runConfig}}
```

It is required to set the work/run directories in $HOME/.cylc/global.rc as follows:
```
  [hosts]
      [[localhost]]
          work directory = /glade/scratch/USERNAME/cylc-run
          run directory = /glade/scratch/USERNAME/cylc-run
          [[[batch systems]]]
              [[[[pbs]]]]
                  job name length maximum = 236
```
It is recommended to also set `job name length maximum` to a large value. Continue reading for 
more documentation aboute drive.csh and run.csh.


Configuration Files
-------------------

The files under the `config/` and `scenarios/` directories describe the configuration for the
entire workflow.  Some files are designed to be modified by users, and others mostly by developers.

### User-modifiable configuration

`config/builds.csh`: describes the build directories for critical applications

`config/scenario.csh`: selection of a particular experiment scenario

For many `config/*.csh` files, there is a one-to-one correspondance with the scenarios/base/\*.yaml.
They are as follows:

```
  scenarios/base/\*.yaml: default user-configurable settings and their descriptions

  scenarios/base/workflow.yaml: cylc task selection and date bounds

  scenarios/base/experiment.yaml: experiment naming conventions

  scenarios/base/model.yaml: model mesh settings

  scenarios/base/observations.yaml: observation source data

  scenarios/base/variational.yaml: settings specific to the variational application

  scenarios/base/hofx.yaml: settings specific to the hofx application

  scenarios/base/job.yaml: account and queue selection
```

While users can directly modify those `base` scripts to achieve their desired configuration,
it is recommended to modify an existing scenario or create their own at
`scenarios/{{ScenarioName}}.yaml`.  Users are referred to the pre-canned scenario
configurations located in `scenarios/*.yaml` and `scenarios/testinput/*.yaml`.
A particular scenario is selected within `config/scenario.csh`. Users may add new scenarios by
copying one of the yaml files in the scenarios directory to a new file, modifying the entries, and
then selecting the new scenario in config/scenario.csh.

### Developer-modifiable configuration

Modifications to these scripts are not necessary for typical users.  However, there are edge cases
outside the design envelope of MPAS-Workflow for which they will need to be extended and/or
refactored.  It is best practice to discuss such modifications that benefit multiple users via
GitHub issues, and to submit pull requests when appropriate.

`config/environment.csh`: run-time environment used across compiled executables and python scripts

`config/filestructure.csh`: workflow file structure

`config/modeldata.csh`: static model-space data file structure, including mesh-specific partition files,
fixed ensemble forecast members for deterministic experiments, first guess files for the first cycle
of an experiment, surface variable update files (sst and xice), and common static.nc file(s) to be
used across all cycles.

`config/obsdata.csh`: static observation-space data file structure; soon to be replaced by
the `observations` configuration section and `observations.csh`

`config/tools.csh`: initializes python tools for workflow task management

`config/verification.csh`: post-processing and verification script descriptions

If a developer wishes to add a new configuration key beyond the current available options, the
recommended procedure is to add the key, default value, and description in one of the `base`
yaml files, then parse the option in the corresponding `config/*.csh` file.  Developers
are referred to the many existing examples and it is recommended to discuss additional options
to be merged back into the GitHub repository via GitHub issues.



#### MPAS configuration (config/mpas/)
Configuration aspects that are unique to `MPAS-Atmosphere`

`config/mpas/geovars.yaml`: list of templated geophysical variables (`GeoVars`) that MPAS-JEDI can
provide to UFO; identical to `mpas-jedi/test/testinput/namelists/geovars.yaml`, but duplicated here
so that users modify it at run-time as needed.

`config/mpas/variables.csh`: model/analysis variables used to generate YAML files for MPAS-JEDI applications


##### Mesh-specific configuration
Mesh-dependent aspects of the configuration; in time, this functionality will migrate to the
scenario yaml files

`config/mpas/$MPASGridDescriptor/mesh.csh`: mesh-specific options for multiple applications
that affect the workflow and application behaviors

`config/mpas/$MPASGridDescriptor/job.csh`: job durations and processor usages

In the above, MPASGridDescriptor describes the mesh selected in the `model` part of the
scenario configuration.  See `scenarios/base/model.yaml` for more information.


##### Application-specific MPAS-Atmosphere configuration

E.g., `namelist.atmosphere`, `streams.atmosphere`, and `stream_list.atmosphere.*`

`config/mpas/forecast/*`: tasks derived from `forecast.csh`

`config/mpas/hofx/*`: tasks derived from `HofX.csh`

`config/mpas/init/*.csh`: `GenerateColdStartIC.csh`

`config/mpas/rtpp/*`: `RTPPInflation.csh`

`config/mpas/variational/*`: `Variational`-type tasks derived from either of `Variational.csh` or
`EnsembleOfVariational.csh`


#### MPAS-JEDI application-specific configuration files
`config/applicationBase/*.yaml`: MPAS-JEDI application-specific YAML templates.  These will be
further populated by scripts templated on `PrepJEDA.csh` and/or `PrepVariational.csh`.

`config/ObsPlugs/variational/*.yaml`: observation yaml stubs that get plugged into `Variational`
`applicationBase` yamls, e.g., `3dvar.yaml`, `3denvar.yaml`, `3dhybrid.yaml`, and
`eda_3denvar.yaml`

`config/ObsPlugs/hofx/*.yaml`: same, but for the `HofX` `applicationBase` yaml, `hofx.yaml`



Main driver: drive.csh
----------------------
Creates a new cylc suite file, then runs it. Users need not modify this file. Developers who wish
to add new cylc tasks, or modify the relationships between tasks, will modify `drive.csh`.
The tasks that are selected in `drive.csh` also the bounding dates of the experiment are
controlled in the `workflow` section of the scenario configuration. Full descriptions of
all options are available in `scenarios/base/workflow.yaml`.  Here we describe only the
`CriticalPathType`, which is integral to running experiments and post-processing.

The `CriticalPathType` determines whether the verification is performed concurrently with and
depends on the critical path (`Normal`) tasks, or as an independent post-processing diagnostic step
(`Bypass`). Setting `CriticalPathType` to either `Reanalysis` or `Reforecast` gives two variations of
"partial cycling", where each cycle is independent and does not depende on any of the previous
cycles. `Reanalysis` is used to perform the `CyclingDA` task on each cycle without re-running
forecasts.  This requires the `CyclingFC` forecast files to already be present in the experiment
directory.  If the user wishes to do this for independently-generated forecasts (i.e., from a
previous separate experiment or a set of forecasts generated outside `MPAS-Workflow`), they
must manually create an experiment directory, then either link or copy the forecast files into the
`CyclingFC` directory following the usual directory structure and file-naming conventions.
`Reforecast` is used to perform forecasts from an existing set of analysis states, which similarly
must be already stored or linked in the `CyclingDA` directory following normal directory structures
and file naming conventions.  It is recommended to run at least one `Normal` experiment to
demonstrate the correct directory structure before trying either of the `Reanalysis` or
`Reforecast` options.


Super driver: run.csh
---------------------
`run.csh` executes `drive.csh` or `SetupWorkflow.csh` for a set of pre-defined
scenarios, each of which must be described in a scenario configuration file (i.e.,
`scenarios/*.yaml`).  The scenario set is selected in `runs/*.yaml`. One of those `run`
configurations is `test.yaml`.  It is recommended to run the `test` scenario set (1) when
a new user first clones the MPAS-Workflow repository and (2) before submitting a GitHub pull request
to [MPAS-Workflow](https://github.com/NCAR/MPAS-Workflow).  For example, execute the following from
the command-line:

```
  source env-script/cheyenne.${YourShell}

  ./run.csh test
  #OR, equivalently,
  ./test.csh
```

Most of the run configurtaions (`runs/*.yaml`) only select a single scenario, except for the
automated test.  When only one scenario is selected, the user can achieve the same effect by
executing `drive.csh` and the choice to use `run.csh` is a matter of personal preference.


Templated workflow tasks
------------------------

These scripts serve as templates for multiple workflow components. The actual task scripts that
are selected via `drive.csh` are generated by performing sed substitution within `SetupWorkflow.csh`
and `AppAndVerify.csh`. Here we give a brief summary of the design and templating for each script.

`CleanHofx.csh`: used to generate `CleanHofX*.csh` scripts, which clean `HofX` working directories
(e.g., `Verification/fc/*`) in order to reduce experiment disk resource requirements.

`CleanVariational.csh`: used to generate `CleanCyclingDA.csh`, which cleans expensive and
easily reproducible files from the `CyclingDA` working directories in order to reduce experiment
disk resource requirements.  This is more important for EDA experiments than for single-state
deterministic cycling.

`EnsembleOfVariational.csh`: used in the `EDAInstance*` cylc task; executes the
`mpasjedi_eda` application.  Similar to `Variational.csh`, except that the EDA is conducted in
a single executable.  Multiple `EDAInstance*` members with a small number of sub-members can
be conducted simultaneously if it is beneficial to group members instead of running them all
independently like what is achieved via `DAMember*` tasks.  Users are referred to
`scenarios/base/variational.yaml` for configuration information.

`forecast.csh`: used to generate all forecast scripts, e.g., `CyclingFC.csh` and `ExtendedMeanFC.csh`,
which execute `mpas_atmosphere` forecasts across a templated time range with state output at a
templated interval. Takes `Variational` analyses or cold-start initial conditions (IC) as inputs.

`HofX.csh`: used to generate all `HofX*` scripts, e.g., `HofXBG.csh`, `HofXMeanFC.csh`, and
`HofXEnsMeanBG.csh`.  Each of those executes the `mpasjedi_hofx3d` application. Templated w.r.t.
the input state directory and prefix, allowing it to read any forecast state written through the
`MPAS-Atmosphere` `da_state` stream.

`PrepJEDI.csh`: substitutes commonly repeated sections in the yaml file for all MPAS-JEDI
applications. Templated w.r.t. the application type (i.e., `variational`, `hofx`) and application
name (e.g., `3denvar`, `hofx`). Prepares `namelist.atmosphere`, `streams.atmosphere`, and
`stream_list.atmosphere.*`.  Links required static files and graph info files that describe MPI
partitioning.

`PrepVariational.csh`: further modifies the application yaml file(s) for the `Variational` task

`Variational.csh`: used in the `DAMember*` cylc task; executes the `mpasjedi_variational`
application.  Templated w.r.t. the background state prefix and directory. Reads one output
forecast state from a `CyclingFCMember*` task, as coded in `SetupWorkflow.csh`.  Multiple instances
can be launched in parallel to conduct an ensemble of data assimilations (EDA).  See
`scenarios/base/variational.yaml` for configuration information.

`verifyobs.csh`: used to generate scripts that verify observation-database output from `HofX` and
`Variational`-type tasks.

`verifymodel.csh`: used to generate scripts that verify model forecast states with respect to GFS
analyses.


Non-templated workflow tasks
----------------------------
These scripts are used as-is without sed substitution.  They are copied to the experiment
workflow directory by `SetupWorkflow.csh`.

`GenerateColdStartIC.csh`: generates cold-start IC files from GFS analyses

`GenerateABEInflation.csh`: generates Adaptive Background Error Inflation (ABEI) factors based on
all-sky IR brightness temperature `H(x_mean)` and `H_clear(x_mean)` from GOES-16 ABI and Himawari-8
AHI

`GetWarmStartIC.csh`: generates links to pre-generated warm-start IC files

`MeanBackground.csh`: calculates the mean of ensemble background states

`MeanAnalysis.csh`: calculates the mean of ensemble analysis states

`ObsToIODA.csh`: converts BUFR and PrepBUFR observation files to IODANC format

`RTPPInflation.csh`: performs Relaxation To Prior Perturbation (RTPP) inflation, taking as input two
ensembles, one each of background states and analysis states


Python tools (`tools/*.py`)
---------------------------
Each of these tools perform a useful part of the workflow that is otherwise cumbersome to achieve
via shell scripts. The argument definitions for each script can be retrieved by executing
`python {{ScriptName}}.py --help` 

`advanceCYMDH`: time-stepping used to figure out dates relative to an arbitrary input date

`getYAMLNode`: retrieves a yaml node key or value from a yaml file

`memberDir`: generates an ensemble member directory string, dependent on experiment- and
application-specific inputs

`nSpaces`: generates a string containing the number of spaces that are input. Used for
controlling indentation of some yaml components

`substituteEnsembleBMembers`: replaced by `substituteEnsembleBTemplate`

`substituteEnsembleBTemplate`: generates and substitutes the ensemble background error
covariance `members from template` configuration into application yamls that match `*envar*`
and `*hybrid*`. See `Variational.csh` for the specific behavior.

`updateXTIME`: updates the `xtime` variable in an `MPAS-Atmosphere` state file so that it can be read
into the model as though it had the correct time stamp

Note for developers: for simple single-processor operations, the preferred practice in
`MPAS-Workflow` is to use python scripts.  Developers are encouraged to try this approach before
writing source-code for a compiled executable that is more onerous to build and maintain.
Single-node multi-processor tasks may also be carried out in python scripts, which is the current
practice in `MPAS-Workflow` verification. However, scalable multi-processor operations, especially
those dealing with complex operations on model state data are often better-handled by compiled
executables.


Some useful cylc commands
-------------------------
1. Print a list of active suites

```
cylc scan
```

2. Open an X-window GUI showing the status of all active suites.

```
cylc gscan
```

Double-click an individual suite in order to see detailed information or navigate between suites
using the drop-down menus.  From the GUI, it is easy to perform actions on the entire suite or
individual tasks, e.g., hold, resume, kill, trigger.  It is also possible to interrogate the
real-time progress the cylc tasks being executed and, in some cases, the next tasks that will be
triggered. There are multiple views available, including a flow chart view that is useful for new
users to learn the dependencies between tasks.

3. Trigger all tasks in a suite with a particular {{STATUS}}.  Examples: failed, submit-failed

```
cylc trigger {{SUITENAME}} '*.*:{{STATUS}}'
```

A note about disk management
----------------------------
This workflow includes automated deletion of some intermediate files.  That behavior can be modified
in scripts that look like `Clean{{Application}}.csh`.  If data storage is still a problem, it is
recommended to remove the `Cycling*` directories of an experiment after all desired verification has
completed. The model- and observation-space statistical summary files in the `Verification`
directory are orders of magnitude smaller than the full model states and instrument feedback files.
