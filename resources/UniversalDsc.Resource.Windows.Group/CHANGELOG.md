# Changelog

All notable changes to the UniversalDsc.Resource.Windows.Group project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-08-04

### Added

- Initial release of UniversalDsc.Resource.Windows.Group
- Support for creating, updating, and deleting Windows local groups
- Group property management (name, description)
- Comprehensive member management capabilities:
  - Exact membership specification with `members` property
  - Additive membership management with `membersToInclude` property
  - Exclusive membership management with `membersToExclude` property
- Support for both users and groups as members
- Full DSC v3 framework integration
