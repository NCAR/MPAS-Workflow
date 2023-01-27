
MPAS-Workflow
=============

A tool for cycling forecast and data assimilation experiments with the
[MPAS-Atmosphere](https://mpas-dev.github.io/) model and the
[JEDI-MPAS](https://jointcenterforsatellitedataassimilation-jedi-docs.readthedocs-hosted.com/en/latest/inside/jedi-components/mpas-jedi/index.html)
data assimilation package. The workflow is orchestrated using the [Cylc](https://cylc.github.io/)
general purpose workflow engine.

Starting a cycling experiment on the Cheyenne HPC
-------------------------------------------------

```shell
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
 #OR
 ./test.csh
```

It is required to set the `work` and `run` directories in $HOME/.cylc/global.rc as follows:
```
[hosts]
  [[localhost]]
    work directory = /glade/scratch/USERNAME/cylc-run
    run directory = /glade/scratch/USERNAME/cylc-run
    [[[batch systems]]]
      [[[[pbs]]]]
        job name length maximum = 236
```
`USERNAME` must be filled in with your user-name.  It is possible to choose different locations for
the cylc `work` and `run` directories, as long as you also modify `cylcWorkDir` in `drive.csh`. It is
recommended to set `job name length maximum` to a large value.

Build
-----
At this time the workflow does not build MPAS-Model or JEDI-MPAS.  Users must to acquire source
code from either [JCSDA/mpas-bundle](https://github.com/JCSDA/mpas-bundle/) or
[JCSDA-internal/mpas-bundle](https://github.com/JCSDA-internal/mpas-bundle/).  Then they must
follow the build instructions in the corresponding repository.  Tagged releases of MPAS-Workflow
starting with 25JAN2023 are accompanied by an mpas-bundle CMakeLists.txt (`build/CMakeLists.txt`)
with fixed source code repository tags/hashes that are consistent with the released workflow
version.  Users can copy that file into their mpas-bundle source code directory before executing 
`ecbuild` in order to download the currect repository versions.

Periodically the `develop` branch of MPAS-Workflow will be consistent with the source code
`develop` branches, usually every 1-2 months.  As often as is feasible, that is when a new tagged
release of MPAS-Workflow will be generated.

As such, the current `develop` branch of MPAS-Workflow may or may not be backward compatible to
those source code tags. For developers, unless they are absolutely sure that their workflow branch
is consistent with a particular  set of source code `develop` branches, it is strongly recommended
that they start their development process from the tagged source code hashes stored in
`build/CMakeLists.txt`.  After checking out the specific source code hashes (via `ecbuild`), it is
simple to generate their own feature or bugfix branches using, e.g.,
`git checkout -b feature/CustomFeature`.

Please contact [JJ Guerrette](mailto:guerrett@ucar.edu?subject=[GitHub]%20MPAS-Worflow) with any
questions. The MPAS-Worklfow release procedure is subject to change in the future, which will be
documented here.

Configuration Files
-------------------

The files under the `config/` and `scenarios/` directories describe the configuration for the
entire workflow.  Some files are designed to be modified by users, and others mostly by developers.

### User-modifiable configuration

`config/builds.csh`: describes external build directories for critical applications

`config/scenario.csh`: selection of a particular experiment scenario

For many `csh` scripts located under `config/` and `config/applications`, there is a one-to-one
correspondance with yaml files located under `scenarios/base/`. For those configuration components,
the `csh` script is used to parse the `yaml` and/or the identically named section of the scenario
`yaml` file (e.g., `scenarios/3dvar_OIE120km_WarmStart.yaml`). The `base` scenario `yaml`'s contain
the default values and documentation for each user-configurable setting.  Those `base`
configuration sections are as follows:

#### cross-application settings

`scenarios/base/experiment.yaml`: experiment naming conventions

`scenarios/base/job.yaml`: account and queue selection

`scenarios/base/model.yaml`: model mesh settings

`scenarios/base/observations.yaml`: observation source data

`scenarios/base/workflow.yaml`: cylc task selection and date bounds

#### application-specific settings

`scenarios/base/ensvariational.yaml`

`scenarios/base/forecast.yaml`

`scenarios/base/hofx.yaml`

`scenarios/base/initic.yaml`

`scenarios/base/rtpp.yaml`

`scenarios/base/variational.yaml`

`scenarios/base/verifyobs.yaml`

`scenarios/base/verifymodel.yaml`

While users can directly modify those `base` `yaml`'s to achieve their desired configuration,
it is recommended to modify one of the existing full scenarios located directly under `scenarios/`
or create a new scenario by copying one of the default scenarios to a new file.  Doing so allows
each user to easily distinguish their custom experimental settings from the the GitHub HEAD branch,
while being able to merge recent repository changes without conflict.  Users may select a
particular scenario, including a custom one of their own making, within `config/scenario.csh`.


### Developer-modifiable configuration

Modifications to these scripts are not necessary for typical users.  However, there are edge cases
outside the design envelope of MPAS-Workflow for which they will need to be extended and/or
refactored.  It is best practice to discuss such modifications that benefit multiple users via
GitHub issues, and then submit pull requests.

`generateExperiment.csh`: produces `cofig/experiment.csh`, which is a global description of the
workflow file structure and file-naming conventions used across multiple applications, partially
derived from `config/naming.csh`

`config/environment.csh`: run-time environment used across compiled executables and python scripts

`config/externalanalyses.csh`: controls how external DA system analysis files are produced,
including online vs. offline.  External analyses are used for verification and for optionally
initializing a cold-start forecast at the first cylce of an experiment.

`config/firstbackground.csh`: controls how the first DA cycle background state is supplied,
including online vs. offline and deterministic vs. ensemble

`config/obsdata.csh`: static observation-space data file structure; soon to be replaced by
the `observations` configuration section and `observations.csh`

`config/tools.csh`: initializes python tools for workflow task management

If a developer wishes to add a new configuration key beyond the current available options, the
recommended procedure is to add the key, default value, and description in one of the `base`
`yaml` files, then parse the option in the corresponding `config/*.csh` file.  Developers
are referred to the many existing examples and it is recommended to discuss additional options
to be merged back into the GitHub repository via GitHub issues.


#### MPAS (`config/mpas/`)
Configuration aspects that are unique to `MPAS-Atmosphere`

`config/mpas/geovars.yaml`: list of templated geophysical variables (`GeoVars`) that MPAS-JEDI can
provide to UFO; identical to `mpas-jedi/test/testinput/namelists/geovars.yaml`, but duplicated here
so that users modify it at run-time as needed.

`config/mpas/variables.csh`: model/analysis variables used to generate `yaml` files for MPAS-JEDI applications


##### Application-specific MPAS-Atmosphere controls

E.g., `namelist.atmosphere`, `streams.atmosphere`, and `stream_list.atmosphere.*`

`config/mpas/forecast/*`: tasks derived from `forecast.csh`

`config/mpas/hofx/*`: tasks derived from `HofX.csh`

`config/mpas/initic/*.csh`: `ExternalAnalysisToMPAS.csh` and `UngribExternalAnalysis.csh`

`config/mpas/rtpp/*`: `RTPPInflation.csh`

`config/mpas/variational/*`: `Variational`-type tasks derived from either of `Variational.csh` or
`EnsembleOfVariational.csh`


#### MPAS-JEDI application-specific controls
The application-specific `yaml` stubs provide a base set of options that are common across most
experiments.  Parts of those stubs are automatically populated via the workflow.  Advanced
users or developers are encouraged to modify the application-specific yamls directly to suit
their needs.

`config/jedi/applications/*.yaml`: MPAS-JEDI application-specific `yaml` templates.  These will be
further populated by scripts templated on `PrepJEDI.csh` and/or `PrepVariational.csh`.

`config/jedi/ObsPlugs/variational/*.yaml`: observation `yaml` stubs that get plugged into `Variational`
`jedi/applications` yamls, e.g., `3dvar.yaml`, `3denvar.yaml`, and `3dhybrid.yaml`

`config/jedi/ObsPlugs/hofx/*.yaml`: same, but for `jedi/applications/hofx.yaml`



Main driver: drive.csh
----------------------
Creates a new cylc suite file, then runs it. Users need not modify this file. Developers who wish
to add new cylc tasks, or modify the relationships between tasks, will modify `drive.csh` and/or
the files in the `include` directory:
- `include/criticalpath.rc`: controls all elements of the critical path for all `CriticalPathType`
options.  Allows for re-use of `include/forecast.rc` and `include/da.rc` according to the user
selections.  Those latter two scripts describe all the intra-forecast and intra-da dependencies,
respectively, independent of tasks in other categories.
- `include/verification.rc`: describes the dependencies between `HofX`, `Verify*`, `Compare*`, and other
kinds of tasks that produce verification statistics files.  It includes dependencies on
`forecast` and `da` tasks that produce the data to be verified.  Multiple aspects of verification
are controlled via the `workflow` section of the scenario configuration. Full descriptions of all
verification options are available in `scenarios/base/workflow.yaml`.
- `include/tasks.rc`: describes all cylc tasks that can be selected under the `[[dependencies]]` node of
`drive.csh`, all of which are described in either `criticalpath.rc`, `verification.rc`, or files
included therein.

See `scenarios/base/workflow.yaml` for user-selectable options that control `drive.csh`.


Super driver: run.csh
---------------------
`run.csh` executes `drive.csh` or `SetupWorkflow.csh` for a set of pre-defined
scenarios, each of which must be described in a scenario configuration file (i.e.,
`scenarios/*.yaml`).  The scenario set is selected in `runs/*.yaml`. One of those `run`
configurations is `test.yaml`.  It is recommended to run the `test` scenario set (1) when
a new user first clones the MPAS-Workflow repository and (2) before submitting a GitHub pull request
to [MPAS-Workflow](https://github.com/NCAR/MPAS-Workflow).  For example, execute the following from
the command-line:

```shell
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

`PrepJEDI.csh`: substitutes commonly repeated sections in the `yaml` file for all MPAS-JEDI
applications. Templated w.r.t. the application type (i.e., `variational`, `hofx`) and application
name (e.g., `3denvar`, `hofx`). Prepares `namelist.atmosphere`, `streams.atmosphere`, and
`stream_list.atmosphere.*`.  Links required static files and graph info files that describe MPI
partitioning.

`PrepVariational.csh`: further modifies the application `yaml` file(s) for the `Variational` task

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

`ExternalAnalysisToMPAS.csh`: generates cold-start IC files from GFS analyses

`GenerateABEInflation.csh`: generates Adaptive Background Error Inflation (ABEI) factors based on
all-sky IR brightness temperature `H(x_mean)` and `H_clear(x_mean)` from GOES-16 ABI and Himawari-8
AHI

`GetWarmStartIC.csh`: generates links to pre-generated warm-start IC files

`MeanBackground.csh`: calculates the mean of ensemble background states

`MeanAnalysis.csh`: calculates the mean of ensemble analysis states

`ObsToIODA.csh`: converts BUFR and PrepBUFR observation files to IODANC format

`RTPPInflation.csh`: performs Relaxation To Prior Perturbation (RTPP) inflation, taking as input two
ensembles, one each of background states and analysis states


Non-task shell scripts
----------------------
`AppAndVerify.csh`: generate "Application" and "Verification" cylc-task shell scripts from the
templated workflow task scripts via `sed` substitution

`getCycleVars.csh`: defines cycle-specific variables, such as multiple formats of the valid date,
and date-resolved directories

`SetupWorkflow.csh`:
1. Generate the experiment directory
2. Copy the current config and scenarios directories to the experiment workflow directory
   so that a record is kept of all settings
3. Copy non-templated task scripts to the experiment directory
4. Generate cylc-task shell scripts from via templated substitution of `AppAndVerify.csh`, then
   execution of application-specific `AppAndVerify*.csh` scripts


Python tools (`tools/*.py`)
---------------------------
Each of these tools perform a useful part of the workflow that is otherwise cumbersome to achieve
via shell scripts. The argument definitions for each script can be retrieved by executing
`python {{ScriptName}}.py --help` 

`advanceCYMDH`: time-stepping used to figure out dates relative to an arbitrary input date

`getYAMLNode`: retrieves a `yaml` node key or value from a `yaml` file

`memberDir`: generates an ensemble member directory string, dependent on experiment- and
application-specific inputs

`nSpaces`: generates a string containing the number of spaces that are input. Used for
controlling indentation of some `yaml` components

`substituteEnsembleBMembers`: replaced by `substituteEnsembleBTemplate`

`substituteEnsembleBTemplate`: generates and substitutes the ensemble background error
covariance `members from template` configuration into application yamls that match `*envar*`
and `*hybrid*`. See `PrepVariational.csh` for the specific behavior.

`updateXTIME`: updates the `xtime` variable in an `MPAS-Atmosphere` state file so that it can be read
into the model as though it had the correct time stamp

Note for developers: for simple single-processor operations, the preferred practice in
`MPAS-Workflow` is to use python scripts.  Developers are encouraged to try this approach before
writing source-code for a compiled executable that is more onerous to build and maintain.
Single-node multi-processor tasks may also be carried out in python scripts, which is the current
practice in `MPAS-Workflow` verification. However, scalable multi-processor operations, especially
those dealing with complex operations on model state data are often better-handled by compiled
executables.


Notes on cylc
-------------
Full documentation on cylc can be found [here](https://cylc.github.io/documentation/). Below are
some useful cylc commands to get new users started.

1. Print a list of active suites
```shell
cylc scan
```

2. Open an X-window GUI showing the status of all active suites.
```shell
cylc gscan
```

Double-click an individual suite in order to see detailed information or navigate between suites
using the drop-down menus.  From the GUI, it is easy to perform actions on the entire suite or
individual tasks, e.g., hold, resume, kill, trigger.  It is also possible to interrogate the
real-time progress of the cylc tasks being executed, and in some cases the next tasks that will be
triggered. There are multiple views available, including a flow chart view that is useful for new
users to learn the dependencies between tasks.

3. Shut down a suite (`SUITENAME`) after killing all active tasks
```shell
cylc stop --kill SUITENAME
```

4. Trigger all tasks in a suite with a particular `STATUS` (e.g., failed, submit-failed)
```shell
cylc trigger SUITENAME "*.*:STATUS"
```

5. Useful c-shell alises based on the above
```csh
alias cylcstopkill "cylc stop --kill \!:1"
# usage:
cylcstopkill SUITENAME

alias cylctriggerfailed "cylc trigger \!:1 '*.*:failed'"
# usage:
cylctriggerfailed SUITENAME

alias cylctriggerstatus "cylc trigger \!:1 '*.*:\!:2'"
# usage:
cylctriggerstatus SUITENAME STATUS
```

A note about disk management
----------------------------
This workflow includes capability for automated deletion of some intermediate files.  The default
behavior is to keep all files, but that can be modified by setting the variational.retainObsFeedback
and/or hofx.retainObsFeedback options to False.  If data storage is still a problem, it is
recommended to remove the `Cycling*` directories of an experiment after all desired verification has
completed. The model- and observation-space statistical summary files in the `Verification`
directory are orders of magnitude smaller than the full model states and instrument feedback files.


References
----------

Liu, Z., Snyder, C., Guerrette, J. J., Jung, B.-J., Ban, J., Vahl, S., Wu, Y., Trémolet, Y., Auligné, T., Ménétrier, B., Shlyaeva, A., Herbener, S., Liu, E., Holdaway, D., and Johnson, B. T.: Data Assimilation for the Model for Prediction Across Scales – Atmosphere with the Joint Effort for Data assimilation Integration (JEDI-MPAS 1.0.0): EnVar implementation and evaluation, Geosci. Model Dev. Discuss. [preprint], https://doi.org/10.5194/gmd-2022-133, in review, 2022

Oliver, H., Shin, M., Matthews, D., Sanders, O., Bartholomew, S., Clark, A., Fitzpatrick, B., van Haren, R., Hut, R., and Drost, N.: Workflow Automation for Cycling Systems, Computing in Science & Engineering, 21, 7–21, https://doi.org/10.1109/mcse.2019.2906593, 2019.

Skamarock, W. C., Klemp, J. B., Duda, M. G., Fowler, L. D., Park, S.-H., and Ringler, T. D.: A Multiscale Nonhydrostatic Atmospheric Model Using Centroidal Voronoi Tesselations and C-Grid Staggering, Monthly Weather Review, 140, 3090–3105, https://doi.org/10.1175/mwr-d-11-00215.1, 2012.


Contributors to-date
--------------------
 - Maryam Abdi-Oskouei
 - Junmei Ban
 - Ivette Hernandez Banos[^+] (ivette@ucar.edu)
 - Jamie Bresch
 - JJ Guerrette[^+] (guerrett@ucar.edu)
 - Soyoung Ha
 - BJ Jung
 - Zhiquan Liu
 - Chris Snyder
 - Craig Schwartz
 - Steven Vahl
 - Yali Wu
 - Yonggang Yu

[^+]: primary repository maintainers/developers

These people have contributed any of the following: GitHub pull requests and review, data, scripts
on which workflow tasks are templated, source code, or critical consultation.
