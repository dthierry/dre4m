# DRE<sup>4</sup>M

## Introduction

DRE<sup>4</sup>M or `dre4m` is a framework for the planing of the technological
makeup of a generic sector. The current incarnation framework coalesces into a
*linear program* (LP). The program was laid out using
[`JuMP`](https://github.com/jump-dev/JuMP.jl), which also serves as the
interface between model and solver. `dre4m` is subject to the terms of the [MIT
license](https://mit-license.org).


<p class="aligncenter"> <img src="../img/dre4mnoback.svg" width="20%" height="20%"
title="dre4m logo"> </p>

## Installation

At the Julia REPL press `]` mode, then `dre4m` can be obtained directly from the
repository as follows,

    add https://github.com/dthierry/dre4m.git

## The `dre4m` layout

The source is organized as follows,

    .
    ├── LICENSE
    ├── Manifest.toml   # julia record of pakages
    ├── Project.toml    # julia dependencies
    ├── README.md   # project readme
    ├── data    # data folder
    │   ├── .
    ├── instance    # case studies folder
    │   └── prototypes  # example prototypes
    │       └── .
    ├── src # main source file
    │   ├── coef    # coefficient functions
    │   │   └── .
    │   ├── dre4m.jl    # julia module
    │   ├── gestalt # problem abstract form
    │   │   └── .
    │   ├── matrix  # data structures
    │   │   └── .
    │   ├── mods    # models
    │   │   └── .
    │   ├── post    # results postprocessing
    │   │   └── .
    │   └── utils   # this generates some useful plots
    │       ├── coalesce_py
    │       │   └── .
    │       └── plot_py
    │           └── .
    └── test    # testing files
        ├── gestalt
        │   └── .
        ├── matrix
        │   └── .
        ├── mods
        │   ├── .
        ├── retrofit
        │   └── .
        └── runtest.jl

## Data requirements 

Before running a problem, please consult the data requirements from the
[input](input.md) page.

## Contributors

- David Thierry, Argonne National Laboratory, *ESIA division*
- Sarang Supekar, Argonne National Laboratory, *ESIA division*

## License
 
`dre4m` is licensed under the 3-Clause BSD [license](license.md). 

Additionally, `dre4m` utilizes several dependencies, which have their own
licences. Refer to their respective repositories for more information about the
licenses.

