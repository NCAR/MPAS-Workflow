
MPAS-Workflow
=============

A tool for cycling forecast and data assimilation experiments with the
[MPAS-Atmosphere](https://mpas-dev.github.io/) model and the
[JEDI-MPAS](https://jointcenterforsatellitedataassimilation-jedi-docs.readthedocs-hosted.com/en/latest/inside/jedi-components/mpas-jedi/index.html)
data assimilation package. The workflow is orchestrated using the [Cylc](https://cylc.github.io/)
general purpose workflow engine.

Starting a cycling experiment on the Derecho HPC
-------------------------------------------------

```shell
 #login to derecho.hpc.ucar.edu

 mkdir -p /fresh/path/for/submitting/experiments

 cd /fresh/path/for/submitting/experiments

 git clone https://github.com/NCAR/MPAS-Workflow

 cd MPAS-Workflow

 #modify configuration as needed in `scenarios/*.yaml`, `scenarios/defaults/*.yaml`, or
 # `test/testinput/*.yaml`

 ./Run.py {{scenarioConfig}}
 #OR
 ./test.csh
```

`{{scenarioConfig}}` is a yaml-based configuration file, examples of which are given in
`scenarios/*.yaml` and `test/testinput/*.yaml`

It is required to set the content of $HOME/.cylc/flow/global.cylc as follows:
```
[platforms]
    # The localhost platform is available by default
    # [[localhost]]
    #     hosts = localhost
    #     install target = localhost
    [[pbs_cluster]]
        hosts = localhost
        job runner = pbs
        install target = localhost
    # to have the cylc run output in your scratch directory uncomment the following 4 lines
    #[install]
    #   [[symlink dirs]]
    #      [[[localhost]]]
    #        run = /glade/derecho/scratch/$USER/
```
The [[pbs_cluster]] entries tell cylc how to submit jobs.
The [instal] section will create both $HOME/cylc-run/MPAS-Workflow and 
/glade/derecho/scratch/$USER/cylc-run/MPAS-Workflow directories to be created.
A symlink will be created in $HOME/cylc-run/MPAS-Workflow for each workflow,
which will point to a directory in the run/cylc-run/MPAS-Workflow where the actual data will be written.

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
python modules/classes in the `initialize/*/` directories.  Each class derived from `Component` is
associated with a root node in the scenario `yaml` file.  For example, `Variational.py` parses the
configuration of the `variational` node, `Forecast.py` parses the `forecast` node, and so on.  The
basic (i.e., `non-resource`) options available for each root `yaml` node are described either as class member
variables or in the class `__init__` method.  The appropriate `yaml` layouts for `resource` options
(e.g., `variational.job` `externalanalyses.resources`, `observations.resources`, `forecast.job`)
are demonstrated in `scenarios/defaults/*.yaml`.  `resource` options are also parsed in the
python modules/classes under `initialize/*`.

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

If a developer wishes to add a new `yaml` node beyond the current available options, the
recommended procedure is to add the option in the appropriate python class, following the examples
in `initialize/*/*.py`.  Developers are referred to the many existing examples, and it is
recommended to discuss additional options to be merged back into the GitHub repository via GitHub
issues and pull requests.


#### MPAS (`config/mpas/`)
Contains static configuration aspects that are unique to `MPAS-Atmosphere`

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
their needs.  If those changes/enhancements would be beneficial for multiple users, please
consider submitting a pull request to share your enhancements.

`config/jedi/applications/*.yaml`: MPAS-JEDI application-specific `yaml` templates.  These will be
further populated by `bin/PrepJEDI.csh` and/or `bin/InitVariationals.csh`.

`config/jedi/ObsPlugs/variational/*.yaml`: observation `yaml` stubs that get plugged into `Variational`
`jedi/applications` yamls, e.g., `3dvar.yaml`, `3denvar.yaml`, and `3dhybrid.yaml`.  The yaml
substitution is carried out by `bin/PrepJEDI.csh`.

`config/jedi/ObsPlugs/hofx/*.yaml`: same, but for `jedi/applications/hofx.yaml`



Main driver: Run.py
-------------------

`Run.py` initiates a single scenario or a list of scenarios, each of which is associated with one
of the pre-defined suites (`initialize/suites/*.py`). Each scenario must be described in
`yaml`-formatted scenario configuration file.  Other than for automated testing
(`test/testinput/test.yaml`), most of the scenario configurations (`scenarios/*.yaml`) only select
a single scenario. It is recommended to run the `test.yaml` list of scenarios both (1) when a new
user first clones the MPAS-Workflow repository and (2) before submitting a GitHub pull request to
[MPAS-Workflow](https://github.com/NCAR/MPAS-Workflow).  For example, execute the following from
the command-line:

```shell
  source env-script/cheyenne.${YourShell}

  ./Run.py test/testinput/test.yaml
  #OR, equivalently,
  ./test.csh
```

`Run.py` (1) parses the selected `{{scenarioConfig}}`, (2) automatically generates a few
`Cylc`-relevant `*.rc` files and `config/auto/*.csh` environment variable files, and (3)
initiates the `Cylc` suite by executing `submit.csh`. Users need not modify `Run.py` or
`submit.csh`.  The file `MPAS-Workflow/suite.rc` is automatically generated in the run
directory, and it describes all suite tasks and dependencies.

Most of the driver functionality is comprised by python scripts in `initialize/`.  Only
they need to be consulted and/or modified.  For example, developers who wish to
add new `Cylc` tasks, or change the relationships (`dependencies`) between tasks, will need
to modify `initialize/*/*.py`, or in rare cases, create a new suite under `initialize/suites/`.
If the new task requires a new shell script, it can be added in the `bin/` directory.  Examples
are available for executing `bin/*.csh` scripts from an auto-generated `Cylc` task in the
`initialize/applications`, `initialize/data`, and `initialize/post` directories.

Workflow task scripts
---------------------

These scripts (`bin/*.csh`) are called from cylc workflow task elements.  Their usage and
relationships are fully described by automatically generated suite.rc snippets.  Those task and
dependency snippets, respectively, are created during the execution of `Run.py`.  That procedure
is carried out by the python scripts under the `initialize/` directory.  Many shell scripts have a
corresponding python class in the `initialize/` directory, or else serve as one task of many in a
`TaskFamily` class member belonging to a derived `Component` class.

`CleanHofx.csh`: used to clean `HofX` working directories (e.g., under `Verification/fc/`) in order
to reduce experiment disk resource requirements.

`HofX.csh`: used to execute the `mpasjedi_hofx3d` application. Can read any forecast state written
 through the `MPAS-Atmosphere` `da_state` stream.

`PrepJEDI.csh`: substitutes commonly repeated sections in the `yaml` file for multiple MPAS-JEDI
applications. The primary purpose is to fill in the `observers` section of `hofx` and `variational`
`yaml` files.  Prepares `namelist.atmosphere`, `streams.atmosphere`, and `stream_list.atmosphere.*`.
Links required static files and graph info files that describe MPI  partitioning.

`VerifyObs.csh`: used to verify observation-database output from `HofX` and `Variational` tasks.

`VerifyModel.csh`: used to verify model forecast states with respect to external analyses (i.e.,
configurable via `initialize/data/ExternalAnalyses.py`).

`ExternalAnalysisToMPAS.csh`: generates cold-start IC files from ungribbed external analyses

`Forecast.csh`: used for all forecast-related `Cylc` tasks, e.g., `Forecast`, `ColdForecast`,
and `ExtendedForecast`, which execute `mpas_atmosphere` for a command-line-argument controlled time
duration and state output interval. Many more command-line arguments allow for extensive flexibility
in the types of tasks to which this script can apply.  See `initialize/applications/Forecast.py`,
`initialize/applications/ExtendedForecast.py`, and `initialize/data/FirstBackground.py` for multiple
use-cases.  Takes `Variational` analyses, or external analyses processed as cold-start initial
conditions (IC), as inputs.

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

 - `InitVariationals.csh`: further modifies the application `yaml` file(s) for the `Variational`
   task. The primary function is to populate the background error covariance and EDA-relevant
   entries.

 - `Variational.csh`: used in the `Variational*` `Cylc` task; executes the `mpasjedi_variational`
   application.  Reads one output forecast state from a `Forecast*` task.  Multiple instances
   can be launched in parallel to conduct an ensemble of data assimilations (EDA).


Non-task shell scripts
----------------------
`bin/getCycleVars.csh`: defines cycle-specific variables, such as multiple formats of the valid date,
and date-resolved directories

`submit.csh`:
1. Source the experiment directory info from `config/auto/experiment.csh`
2. Check if suite is already running; kill if it is
3. Submit the suite


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
and `*hybrid*`. See `InitVariationals.csh` for the specific behavior.

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
users to learn the dependencies between tasks and families of tasks.

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


Contributions
-------------

<!-- Any time this section is updated, it should be copied verbatim to the NOTICE file, consistent
with the Apache-2 LICENSE file. Contributors are to be listed alphabetically by surname.-->

`MPAS-Workflow` is provided by NCAR/MMM as an example for carrying out DA and non-DA
workflows with MPAS and JEDI-MPAS. The contributors have provided any of the following:
 - GitHub pull requests and/or review
 - data
 - shell scripts used by workflow tasks 
 - workflow design
 - source code
 - other critical consultation

Contributors:
 - Maryam Abdi-Oskouei
 - Junmei Ban
 - Ivette Hernandez Banos
 - Jamie Bresch
 - JJ Guerrette
 - Soyoung Ha
 - BJ Jung
 - Zhiquan Liu
 - Chris Snyder
 - Craig Schwartz
 - Steven Vahl
 - Yali Wu
 - Yonggang Yu
