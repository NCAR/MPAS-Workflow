
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

 #modify configuration as needed in `scenarios/*.yaml`, `scenarios/defaults/*.yaml`, or
 # `test/testinput/*.yaml`

 source env-setup/cheyenne.csh
 #OR
 source env-setup/cheyenne.sh

 ./Run.py {{scenarioConfig}}
 #OR
 ./test.csh
```

`{{scenarioConfig}}` is a yaml-based configuration file, examples of which are given in
`scenarios/*.yaml` and `test/testinput/*.yaml`

It is required to set the `work` and `run` directories in $HOME/.cylc/global.rc as follows:
```
[hosts]
  [[localhost]]
    work directory = /glade/scratch/USER/cylc-run
    run directory = /glade/scratch/USER/cylc-run
    [[[batch systems]]]
      [[[[pbs]]]]
        job name length maximum = 236
```
`USER` must be filled in with your user-name.  It is
recommended to set `job name length maximum` to a large value.

Build
-----
At this time the workflow does not build MPAS-Model or JEDI-MPAS.  Users must acquire source
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
is consistent with a particular set of source code `develop` branches, it is strongly recommended
that they start their development process from the tagged source code hashes stored in
`build/CMakeLists.txt`.  After checking out those specific source code hashes (via `ecbuild`), it is
simple to generate their own feature or bugfix branches using, e.g.,
`git checkout -b feature/CustomFeature`.

Please contact [JJ Guerrette](mailto:guerrett@ucar.edu?subject=[GitHub]%20MPAS-Worflow) with any
questions. The MPAS-Worklfow release procedure is subject to change in the future, which will be
documented here.

Configuration Files
-------------------

The files under the `scenarios/` directories describe the configuration for a particular instance
of an `MPAS-Workflow` `Cylc` suite.  `scenarios/defaults/*.yaml` describe some default
`resource`-based options that users may select in their experiment scenario `yaml` (e.g., 
`scenarios/*.yaml`.  Both the `defaults` and the particular scenario selected are parsed with
python-based classes in the `initialize/components/` directory.  Each `component` is associated
with a particular root `yaml` node.  For example, `Variational.py` parses the configuration of the
`variational` node, `Forecast.py` parses the `forecast` node, and so on.  The basic (i.e.,
`non-resource`) options available for each root `yaml` node are described either as class member
variables or in the class `__init__` method.  The appropriate `yaml` layouts for `resource` options
(e.g., `variational.job` `externalanalyses.resources`, `observations.resources`, `forecast.job`)
are demonstrated in `scenarios/defaults/*.yaml`.  `resource` options are also parsed in the
`initialize/components/` python classes.

#### cross-application `resource` options

`scenarios/defaults/externalanalyses.csh`: controls how external DA system analysis files are produced,
including online vs. offline.  External analyses are used for verification and for optionally
initializing a cold-start forecast at the first cycle of an experiment.

`scenarios/defaults/firstbackground.csh`: controls how the first DA cycle background state is supplied,
including online vs. offline and deterministic vs. ensemble

`scenarios/defaults/model.yaml`: model mesh settings

`scenarios/defaults/observations.yaml`: observation source data

`scenarios/defaults/staticstream.yaml`: controls how the static stream file is supplied.  Defaults to
using the externalanalyses from the first cycle

#### application-specific `resource` options

`scenarios/defaults/forecast.yaml`

`scenarios/defaults/hofx.yaml`

`scenarios/defaults/initic.yaml`

`scenarios/defaults/rtpp.yaml`

`scenarios/defaults/variational.yaml`

`scenarios/defaults/verifyobs.yaml`

`scenarios/defaults/verifymodel.yaml`

It is recommended only to modify the `default` `yaml`'s in order to add or change the `resource`
settings.  Otherwise it is recommended for users to modify their selected abridged scenario `yaml`,
i.e., `scenarios/*.yaml`.  Another possible user workflow is to create a new scenario by copying
one of the default scenarios to a new file.  Doing so allows each user to easily distinguish their
custom experimental settings from the the GitHub HEAD branch, while being able to merge upstream
repository changes without conflict.  Users may select a particular scenario, including a custom
one of their own making, with the aforementioned command, `./Run.py {{scenarioConfig}}`.


### Developer-modifiable configuration

Modifications to these scripts are not necessary for typical users.  However, there are edge cases
outside the design envelope of MPAS-Workflow for which they will need to be extended and/or
refactored.  It is best practice to discuss such modifications that benefit multiple users via
GitHub issues, and then submit pull requests.

`config/environmentJEDI.csh`: run-time environment used across compiled mpas-bundle executables

`config/tools.csh`: initializes python tools for workflow task management

If a developer wishes to add a new `yaml` key beyond the current available options, the
recommended procedure is to add the option in the appropriate python class, following the examples
in `initialize/components/*.py`.  Developers are referred to the many existing examples and it is
recommended to discuss additional options to be merged back into the GitHub repository via GitHub
issues and pull requests.


#### MPAS (`config/mpas/`)
Configuration aspects that are unique to `MPAS-Atmosphere`

`config/mpas/geovars.yaml`: list of templated geophysical variables (`GeoVars`) that MPAS-JEDI can
provide to UFO; identical to `mpas-jedi/test/testinput/namelists/geovars.yaml`, but duplicated here
so that users modify it at run-time as needed.

`config/mpas/variables.csh`: model/analysis variables used to generate `yaml` files for MPAS-JEDI applications


##### Application-specific MPAS-Atmosphere controls

E.g., `namelist.atmosphere`, `streams.atmosphere`, and `stream_list.atmosphere.*`

`config/mpas/forecast/*`: tasks using `Forecast.csh`

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



Main driver: Run.py
-------------------

`Run.py` initiates one of the suites (`suites/*.rc`) for either a single scenario or a list of
scenarios, each of which must be described in a scenario configuration file.  Other than for
automated testing (`test/testinput/test.yaml`), most of the scenario configurations
(`scenarios/*.yaml`) only select a single scenario. It is recommended to run the `test.yaml`
list of scenarios both (1) when a new user first clones the MPAS-Workflow repository and (2) before
submitting a GitHub pull request to [MPAS-Workflow](https://github.com/NCAR/MPAS-Workflow).  For
example, execute the following from the command-line:

```shell
  source env-script/cheyenne.${YourShell}

  ./Run.py test/testinput/test.yaml
  #OR, equivalently,
  ./test.csh
```

`Run.py` parses the selected `{{scenarioConfig}}`, automatically generates many
`Cylc` `include/*/auto/*.rc` files and `config/auto/*.csh` environment variable files, and finally
initiates the `Cylc` suite by executing `drive.csh`. Users need not modify `Run.py` or `drive.csh`.

There are additional aspects of the driver in `drive.csh`, `initialize/`, and `suites/*.rc`.  For
most users and developers, only `initialize/components` will need to be consulted and/or modified. 

Developers who wish to add new `Cylc` tasks, or change the relationships between tasks, may wish to
modify `include/dependencies/*.rc`, `include/tasks/*.rc`, or `initialize/components/*.py`, or in
rare cases, create their own suite.

- `include/dependencies/criticalpath.rc`: controls the relationships between the critical path task
  elements for the `suites/Cycle.rc` suite, in particular for all possible `CriticalPathType`
  options.  Allows for re-use of `include/tasks/auto/forecast.rc` and `include/tasks/auto/da.rc`
  (generated automatically from from `initialize/components/Forecast.py` and
  `initialize/components/DA.py`) according to the user's scenario `yaml` selections.
- `include/dependencies/verifyobs.rc` and `include/dependencies/verifymodel.rc`: describe the
  dependencies between `HofX`, `Verify*`, `Compare*`, and other kinds of tasks that produce
  verification statistics files.  These include dependencies on tasks in
  `include/tasks/auto/forecast.rc` and `include/tasks/auto/da.rc` that produce the data to be
  verified.  Multiple aspects of verification are controlled via the `workflow` section of the
  scenario configuration. Full descriptions of all verification options are available in
  `initialize/components/Workflow.py`.
- `include/tasks/verify.rc`: describes particular instances of verification-related `Cylc` tasks.
  This file differs from the base task descriptions, which are automatically generated by
`initialize/components/*.py` in the following locations:
  - `include/tasks/auto/extendedforecast.rc`
  - `include/tasks/auto/hofx.rc`
  - `include/tasks/auto/verifymodel.rc`
  - `include/tasks/auto/verifyobs.rc`
- `include/tasks/base.rc`: contains some base `Cylc` task descriptors that are inherited
  by child tasks. Look for the `inherit` keyword for examples.


Templated workflow tasks
------------------------

These scripts (`applications/*.csh`) serve as templates for multiple workflow components. In some
cases, the actual shell scripts that are selected within `include/tasks/*.rc` and
`include/tasks/auto/*.rc` are generated by performing sed substitution within `SetupWorkflow.csh`
and `applications/AppAndVerify.csh`. Here we give a brief summary of the design and templating for
each application script.

`CleanHofx.csh`: used to generate `CleanHofX*.csh` scripts, which clean `HofX` working directories
(e.g., `Verification/fc/*`) in order to reduce experiment disk resource requirements.

`HofX.csh`: used to generate all `HofX*` scripts, e.g., `HofXBG.csh`, `HofXMeanFC.csh`, and
`HofXEnsMeanBG.csh`.  Each of those executes the `mpasjedi_hofx3d` application. Templated w.r.t.
the input state directory and prefix, allowing it to read any forecast state written through the
`MPAS-Atmosphere` `da_state` stream.

`PrepJEDI.csh`: substitutes commonly repeated sections in the `yaml` file for multiple MPAS-JEDI
applications. Templated w.r.t. the application type (i.e., `variational`, `hofx`) and application
name (e.g., `3denvar`, `3dvar`, `hofx`). Prepares `namelist.atmosphere`, `streams.atmosphere`, and
`stream_list.atmosphere.*`.  Links required static files and graph info files that describe MPI
partitioning.

`verifyobs.csh`: used to generate scripts that verify observation-database output from `HofX` and
`Variational`-type tasks.

`verifymodel.csh`: used to generate scripts that verify model forecast states with respect to
external analyses (i.e., configurable via `initialize/components/ExternalAnalyses.py`).


Non-templated workflow tasks
----------------------------
These scripts (also located at `applications/*.csh`) are used as-is without sed substitution.
They are copied to the experiment workflow directory by `SetupWorkflow.csh` or by
`applications/AppAndVerify.csh`.

`ExternalAnalysisToMPAS.csh`: generates cold-start IC files from ungribbed external analyses

`Forecast.csh`: used for all forecast-related `Cylc` tasks, e.g., `Forecast` and `ExtendedMeanFC`,
which execute `mpas_atmosphere` for a command-line-argument controlled time duration and state
output interval. Many more command-line arguments allow for extensive flexibility in the types of
tasks to which this script can apply.  See initialize/components/Forecast.py and ExtendedForecast.py
for multiple use-cases.  Takes `Variational` analyses, or external analyses processed as cold-start
initial conditions (IC), as inputs.

`GenerateABEInflation.csh`: generates Adaptive Background Error Inflation (ABEI) factors based on
all-sky IR brightness temperature `H(x_mean)` and `H_clear(x_mean)` from GOES-16 ABI and Himawari-8
AHI

`LinkWarmStartBackgrounds.csh`: generates links to pre-generated warm-start IC files

`MeanBackground.csh`: calculates the mean of ensemble background states

`MeanAnalysis.csh`: calculates the mean of ensemble analysis states

`ObsToIODA.csh`: converts BUFR and PrepBUFR observation files to IODANC format

`RTPPInflation.csh`: performs Relaxation To Prior Perturbation (RTPP), taking as input the
background and analysis ensembles of the ensemble of `Variational*` tasks

`Variational`-related:
 - `CleanVariational.csh`: optionally cleans expensive and reproducible files from the `CyclingDA`
   working directories in order to reduce experiment disk resource requirements.  This is most
   important for EDA experiments than for single-state deterministic cycling. The relevant scenario
   option is `variational.retainObsFeedback`.

 - `EnsembleOfVariational.csh`: used in the `EDA*` `Cylc` task; executes the
   `mpasjedi_eda` application.  Similar to `Variational.csh`, except that the EDA is conducted in
   a single executable.  Multiple `EDA*` members with a small number of sub-members can
   be conducted simultaneously if it is beneficial to group members instead of running them all
   independently like what is achieved via `Variational*` member tasks.

 - `PrepVariational.csh`: further modifies the application `yaml` file(s) for the `Variational`
   task. The primary function is to populate the background error covariance and EDA-relevant
   entries.

 - `Variational.csh`: used in the `Variational*` `Cylc` task; executes the `mpasjedi_variational`
   application.  Reads one output forecast state from a `Forecast*` task.  Multiple instances
   can be launched in parallel to conduct an ensemble of data assimilations (EDA).



Non-task shell scripts
----------------------
`applications/AppAndVerify.csh`: generate "Application" and "Verification" `Cylc`-task shell scripts
from the templated workflow task scripts via `sed` substitution.  Note that although this script
performs sed substitution on some non-templated `*Variational.csh` scripts, those scripts are
completely non-templated.  Only the `Variational` verification and `PrepJEDIVaritional.csh` scripts
are templated.

`getCycleVars.csh`: defines cycle-specific variables, such as multiple formats of the valid date,
and date-resolved directories

`SetupWorkflow.csh`:
1. Source the experiment directory info from `config/auto/experiment.csh`
2. Copy some non-templated application scripts to the experiment directory
3. Copy the `config`, `include`, `scenarios`, `suites`, `test`, and `tools` directories
   to the experiment workflow directory so that a record is kept of all settings
4. Generate application shell scripts via templated substitution of
   `applications/AppAndVerify.csh`, then execution of application-specific
   `applications/AppAndVerify*.csh` scripts


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


Notes on `Cylc`
---------------
Full documentation on `Cylc` can be found [here](https://cylc.github.io/documentation/). Below are
some useful `Cylc` commands to get new users started.

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
real-time progress of the `Cylc` tasks being executed, and in some cases the next tasks that will be
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
behavior is to keep all files, but that can be modified by setting the
`variational.retainObsFeedback` and/or `hofx.retainObsFeedback` options to False.  If data storage
is still a problem, it is recommended to remove the `Cycling*/` directories of an experiment after
all desired verification has completed. The model- and observation-space statistical summary files
generated under the `Verification/` directory are orders of magnitude smaller than the full model
states and instrument feedback files.


References
----------

Liu, Z., Snyder, C., Guerrette, J. J., Jung, B.-J., Ban, J., Vahl, S., Wu, Y., Trémolet, Y., Auligné, T., Ménétrier, B., Shlyaeva, A., Herbener, S., Liu, E., Holdaway, D., and Johnson, B. T.: Data Assimilation for the Model for Prediction Across Scales – Atmosphere with the Joint Effort for Data assimilation Integration (JEDI-MPAS 1.0.0): EnVar implementation and evaluation, Geosci. Model Dev., 15, 7859–7878, https://doi.org/10.5194/gmd-15-7859-2022, 2022

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
