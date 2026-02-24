# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test suite for validators
- `requirements.txt` for dependency management
- `requirements-dev.txt` for development dependencies
- `setup.py` for Python package installation
- `Makefile` with common development tasks
- `CONTRIBUTING.md` with contribution guidelines
- GitHub Actions CI/CD workflow
- `docker-compose.dev.yml` for development overrides
- Enhanced `.gitignore` for Python projects
- Copy script (`copy_to_home.sh`) for easy deployment

### Changed
- Improved `.gitignore` to include Python and IDE-specific patterns

### Fixed
- N/A

## [1.0.0] - 2024-02-21

### Added
- Separate node ID circles for Controllers and Brokers
- Updated JMX Prometheus exporter to latest version
- Prometheus Java Agent integration
- Professional logging module with colored output
- Comprehensive configuration validation
- Support for resource profiles (small/medium/large)
- KRaft mode support (ZooKeeper-less)
- Multiple Kafka component generators:
  - Broker Generator
  - Controller Generator
  - ZooKeeper Generator
  - Schema Registry Generator
  - Kafka Connect Generator
  - ksqlDB Generator
  - Control Center Generators
- Monitoring stack (Prometheus, Grafana, AlertManager)
- JMX monitoring and metrics export
- Rack awareness for fault tolerance
- Docker image customization with traffic control
- Comprehensive README documentation
- Configuration file support
- Command-line argument parsing
- Jinja2 template-based generation

### Changed
- Updated to Confluent Platform 8.0.0
- Improved broker and controller configuration
- Enhanced Docker Compose template structure
- Better port allocation strategy

### Fixed
- Various bug fixes and improvements

## [0.1.0] - Initial Release

### Added
- Initial project structure
- Basic Kafka cluster generation
- ZooKeeper support
- Docker Compose template

---

## Release Types

- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Vulnerability fixes

[Unreleased]: https://github.com/yourusername/kafka-docker-composer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/kafka-docker-composer/releases/tag/v1.0.0
[0.1.0]: https://github.com/yourusername/kafka-docker-composer/releases/tag/v0.1.0
