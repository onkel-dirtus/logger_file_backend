# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## v0.1.0

### Enhancements

- Add support for custom formatters via `:formatter` option ([#87](https://github.com/onkel-dirtus/logger_file_backend/pull/87))
- Add output truncation support with configurable `:truncate` option (default: 4096 characters) ([#81](https://github.com/onkel-dirtus/logger_file_backend/issues/81))
- Add `:level_mode` option for exact level filtering (`:exact`) vs. minimum level (`:minimum`, default) ([#82](https://github.com/onkel-dirtus/logger_file_backend/issues/82))

### Fixes

- Fix file descriptor leak when removing backend - now properly closes files on termination ([#68](https://github.com/onkel-dirtus/logger_file_backend/issues/68))

### Documentation

- Add comprehensive documentation for log rotation feature ([#86](https://github.com/onkel-dirtus/logger_file_backend/issues/86))
- Document custom formatter usage
- Document output truncation and level filtering options

## v0.0.14

- fix warnings about the use of deprecated :warn
- Bumps versions of `credo` and `ex_doc` to latest

## v0.0.13

- Docs cleanup
- Release file handle
- Bumps versions of `credo` and `ex_doc` to latest

## v0.0.12 - 2021-07-19

- Bumps dependency versions
- Combing through documentation

## v0.0.11 - 2019-08-06

### Enhancements

- Add simple strategy to rotate log files ([3a4d7f](https://github.com/mstratman/logger_file_backend/commit/3a4d7ffea4fd1ea4f4ba2629051efc259dd668ec))
- Allow :all in :metadata option ([#54](https://github.com/onkel-dirtus/logger_file_backend/pull/54))

### Fixes

- Documentation fix ([#39](https://github.com/onkel-dirtus/logger_file_backend/pull/39))
- Eliminate warnings ([#30](https://github.com/onkel-dirtus/logger_file_backend/pull/30), [361c7d](https://github.com/mstratman/logger_file_backend/commit/361c7d81cb408a8aee824d080e16fd26f1920621), [1f0390](https://github.com/mstratman/logger_file_backend/commit/1f0390b29fe90516bd4b70d82250de065900fd41), [#43](https://github.com/onkel-dirtus/logger_file_backend/pull/43))

### Changes

- Update dependencies ([#30](https://github.com/onkel-dirtus/logger_file_backend/pull/30))
