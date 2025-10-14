# openMINDS_KG_Sync

[![Version Number](https://img.shields.io/github/v/release/ehennestad/openminds-kg-sync?label=version)](https://github.com/ehennestad/openminds-kg-sync/releases/latest)
[![View OMKG Sync Toolbox on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://se.mathworks.com/matlabcentral/fileexchange/182309-openminds-kg-sync-toolbox)
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/ehennestad/openminds-kg-sync/actions/workflows/test-code.yml)
[![codecov](https://codecov.io/gh/ehennestad/openminds-kg-sync/graph/badge.svg?token=JZNUFC2953)](https://codecov.io/gh/ehennestad/openminds-kg-sync)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/openminds-kg-sync/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/openminds-kg-sync/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/openminds-kg-sync/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/openminds-kg-sync/graphs/commit-activity)

Sync openMINDS metadata to and from EBRAINS KG

## Description

Provides methods for authenticating with EBRAINS services and upload and download metadata to the EBRAINS Knowledge Graph using openMINDS metadata types

## Requirements and installation
It is recommended to use **MATLAB R2021b** or later.

Users or developers who clone the repository using git can use [MatBox](https://github.com/ehennestad/MatBox) to quickly install this project's [requirements](./requirements.txt):

```matlab
omkgsynctools.installMatBox() % If MatBox is not installed
matbox.installRequirements(path/to/toolboxRootDir)
```

## Getting started

### Syntax examples

Listing types from a KG space:
```
persons = kglist("Person", space="common", from=1, size=20)
```

Pulling individual instances from KG:
``` matlab
someInstance = kgpull(kgIdentifier)
```

Saving instances to KG:
``` matlab
kgsave(someInstance)
```


### Getting started tutorial
See the [Getting Started](https://github.com/ehennestad/openminds-kg-sync/blob/main/docs/GettingStarted.md) tutorial

## Contributing
Please see the [Contributing guidelines](.github/CONTRIBUTING.md) and the [Developer notes](.github/DeveloperNotes.md)

## License

This project is available under the MIT License. See the LICENSE file for details.

## Author

Eivind Hennestad (eivihe@uio.no)
University of Oslo / Neural Systems
