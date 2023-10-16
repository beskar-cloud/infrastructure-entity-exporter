# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.8] - 2023-07-10
### Fixed
- Change problematic openstack call parameter

## [1.2.7] - 2023-07-07
### Fixed
- Allow existence of orphaned/orphaned/entity

## [1.2.6] - 2022-12-23
### Added
- ostack dump: secs_to_HMS() to improve log readability

## [1.2.5] - 2022-12-23
### Changed
- ostack dump: objects with no projects are now in directory "unknown-orphaned"

## [1.2.4] - 2022-12-23
### Fixed
- ostack dump: at_exit() syntax fix

## [1.2.3] - 2022-12-23
### Fixed
- ostack dump: safer json spliting operations
- ostack dump: improved logging

## [1.2.2] - 2022-06-18
### Fixed
- ostack dump: loadbalancer & floating-ip id object detection fix

## [1.2.1] - 2022-06-18
### Fixed
- ostack dump: loadbalancer export fix

## [1.2.0] - 2022-06-18
### Added
- ostack dump: export of floating-ips, loadbalancers, networks, subnets and routers

## [1.1.0] - 2022-06-16
### Changed
- ostack dump: help added, steps added

## [1.0.1] - 2022-06-16
### Changed
- ostack normalization drops disk_available_least and do not touch raw files

## [1.0.0] - 2022-06-16
### Added
- Initial release
