# Contributing to Kafka Docker Composer

Thank you for your interest in contributing to Kafka Docker Composer! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:
- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/kafka-docker-composer.git
   cd kafka-docker-composer
   ```
3. **Add the upstream repository**:
   ```bash
   git remote add upstream https://github.com/original-owner/kafka-docker-composer.git
   ```

## Development Setup

### Prerequisites

- Python 3.7 or higher
- Docker and Docker Compose
- Git

### Installation

1. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Install development dependencies (optional):
   ```bash
   pip install pylint black pytest pytest-cov
   ```

### Running the Application

Generate a simple cluster:
```bash
python3 kafka_docker_composer.py -b 3 -c 3
```

## Project Structure

```
kafka-docker-composer/
├── kafka_docker_composer.py    # Main application entry point
├── constants.py                # Configuration constants
├── logger.py                   # Logging utilities
├── validator.py                # Configuration validation
├── generators/                 # Component generators
│   ├── broker_generator.py
│   ├── controller_generator.py
│   ├── zookeeper_generator.py
│   ├── schema_registry_generator.py
│   ├── connect_generator.py
│   ├── ksqldb_generator.py
│   └── control_center_generator.py
├── docker-generator/
│   └── templates/             # Jinja2 templates
│       ├── docker-compose.j2
│       └── prometheus.j2
├── scripts/                   # Utility scripts
├── tests/                     # Unit tests
└── README.md                 # Documentation
```

## Coding Standards

### Python Style Guide

We follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) with these specific guidelines:

1. **Indentation**: 4 spaces (no tabs)
2. **Line Length**: Maximum 100 characters
3. **Naming Conventions**:
   - Classes: `PascalCase`
   - Functions/methods: `snake_case`
   - Constants: `UPPER_CASE`
   - Private methods: `_leading_underscore`

4. **Docstrings**: Use Google-style docstrings
   ```python
   def example_function(param1, param2):
       """
       Brief description of function.

       Detailed description if needed.

       Args:
           param1: Description of param1
           param2: Description of param2

       Returns:
           Description of return value

       Raises:
           ExceptionType: When this exception is raised
       """
       pass
   ```

5. **Type Hints**: Encourage but not required
   ```python
   def process_config(config: dict) -> bool:
       """Process configuration and return success status."""
       pass
   ```

### Code Formatting

We recommend using `black` for automatic formatting:
```bash
black kafka_docker_composer.py
```

Or use the Makefile:
```bash
make format
```

### Linting

Run pylint before submitting:
```bash
pylint kafka_docker_composer.py
# or
make lint
```

## Testing

### Running Tests

Run all tests:
```bash
python3 -m unittest discover -s . -p "test_*.py" -v
# or
make test
```

Run with coverage:
```bash
pytest --cov=. --cov-report=html
# or
make coverage
```

### Writing Tests

1. Create test files with `test_` prefix
2. Inherit from `unittest.TestCase`
3. Test method names should start with `test_`
4. Aim for >80% code coverage

Example test structure:
```python
import unittest
from module import function_to_test

class TestModuleName(unittest.TestCase):
    """Test suite for module_name"""

    def setUp(self):
        """Set up test fixtures"""
        pass

    def test_basic_functionality(self):
        """Test basic functionality"""
        result = function_to_test()
        self.assertEqual(result, expected_value)

    def test_error_handling(self):
        """Test error conditions"""
        with self.assertRaises(ExpectedException):
            function_to_test(invalid_input)
```

## Submitting Changes

### Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write clean, well-documented code
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   make test
   make lint
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```

   Commit message format:
   ```
   Type: Brief summary (50 chars or less)

   Detailed explanation of what changed and why.
   Include any breaking changes or migration notes.

   Fixes #123
   ```

   Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request** on GitHub

### Pull Request Guidelines

- **Title**: Clear, descriptive summary
- **Description**: Explain what and why
- **Tests**: Include tests for new features
- **Documentation**: Update README.md if needed
- **Single Purpose**: One feature/fix per PR
- **Review Ready**: Ensure CI passes

## Reporting Bugs

### Before Submitting

1. Check existing issues
2. Try the latest version
3. Verify it's reproducible

### Bug Report Template

```markdown
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Run command: `python3 kafka_docker_composer.py ...`
2. Observe error: ...

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- OS: Ubuntu 22.04
- Python: 3.10.5
- Docker: 24.0.0
- Version: 1.0.0

**Logs**
```
Paste relevant logs here
```

**Additional Context**
Any other information
```

## Feature Requests

We welcome feature requests! Please:

1. Check if it already exists
2. Describe the use case
3. Explain the benefit
4. Suggest implementation (optional)

### Feature Request Template

```markdown
**Feature Description**
What feature would you like?

**Use Case**
Why is this feature needed?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other ways to achieve this?

**Additional Context**
Any other information
```

## Development Tips

### Common Tasks

**Generate a test cluster**:
```bash
python3 kafka_docker_composer.py -b 3 -c 3 -s 1 -C 1
docker compose up -d
```

**View logs**:
```bash
docker compose logs -f broker1
```

**Clean up**:
```bash
docker compose down -v
make clean
```

### Debugging

Enable debug logging:
```bash
python3 kafka_docker_composer.py -b 3 -c 3 --debug
```

### Adding a New Generator

1. Create file in `generators/` directory
2. Inherit from appropriate base class
3. Implement `generate()` method
4. Import in `kafka_docker_composer.py`
5. Add instantiation logic
6. Add tests in `test_generators.py`
7. Update documentation

## Questions?

If you have questions:
- Open an issue with the `question` label
- Check existing documentation
- Review closed issues for similar questions

Thank you for contributing!
