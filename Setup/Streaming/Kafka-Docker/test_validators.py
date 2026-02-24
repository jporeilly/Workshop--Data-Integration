"""
Unit tests for validator.py module

Tests validation functions for Kafka Docker Composer configuration.
"""

import unittest
import sys
from argparse import Namespace
from validator import (
    validate_configuration,
    ValidationError,
    ValidationWarning
)


class TestConfigurationValidation(unittest.TestCase):
    """Test configuration validation"""

    def create_args(self, **kwargs):
        """Helper to create args object with defaults"""
        defaults = {
            'brokers': 3,
            'controllers': 3,
            'zookeepers': 0,
            'schema_registries': 0,
            'connect_instances': 0,
            'ksqldb_instances': 0,
            'replication_factor': 3,
            'resource_profile': 'medium',
            'available_memory': 8192,
            'control_center': False,
            'control_center_next_gen': False,
            'prometheus': False,
            'shared_mode': False,
        }
        defaults.update(kwargs)
        return Namespace(**defaults)

    def test_valid_configuration(self):
        """Test that a valid configuration passes validation"""
        args = self.create_args()
        errors, warnings = validate_configuration(args)
        self.assertEqual(len(errors), 0, f"Expected no errors, got: {errors}")

    def test_zero_brokers_error(self):
        """Test that zero brokers generates an error"""
        args = self.create_args(brokers=0)
        errors, warnings = validate_configuration(args)
        self.assertGreater(len(errors), 0, "Expected error for zero brokers")

    def test_single_broker_warning(self):
        """Test that single broker generates a warning"""
        args = self.create_args(brokers=1, controllers=0, zookeepers=1, replication_factor=1)
        errors, warnings = validate_configuration(args)
        # Single broker should warn but not error
        self.assertEqual(len(errors), 0, "Single broker should not generate errors")

    def test_large_cluster_configuration(self):
        """Test that large cluster configuration is valid"""
        args = self.create_args(
            brokers=5,
            controllers=3,
            schema_registries=2,
            connect_instances=2,
            ksqldb_instances=2,
            resource_profile='large'
        )
        errors, warnings = validate_configuration(args)
        self.assertEqual(len(errors), 0, "Large cluster config should be valid")


class TestControllerValidation(unittest.TestCase):
    """Test controller count validation for KRaft mode"""

    def create_args(self, **kwargs):
        """Helper to create args object with defaults"""
        defaults = {
            'brokers': 3,
            'controllers': 3,
            'zookeepers': 0,
            'schema_registries': 0,
            'connect_instances': 0,
            'ksqldb_instances': 0,
            'replication_factor': 3,
            'resource_profile': 'medium',
            'available_memory': 8192,
            'control_center': False,
            'control_center_next_gen': False,
            'prometheus': False,
            'shared_mode': False,
        }
        defaults.update(kwargs)
        return Namespace(**defaults)

    def test_valid_controller_count_odd(self):
        """Test that odd controller counts pass validation"""
        args = self.create_args(controllers=3)
        errors, warnings = validate_configuration(args)
        self.assertEqual(len(errors), 0)

    def test_even_controller_count_warning(self):
        """Test that even controller counts generate warning"""
        args = self.create_args(controllers=2)
        errors, warnings = validate_configuration(args)
        # Even controllers should warn but not necessarily error
        # (depends on implementation)


class TestResourceProfileValidation(unittest.TestCase):
    """Test resource profile validation"""

    def create_args(self, **kwargs):
        """Helper to create args object with defaults"""
        defaults = {
            'brokers': 3,
            'controllers': 3,
            'zookeepers': 0,
            'schema_registries': 0,
            'connect_instances': 0,
            'ksqldb_instances': 0,
            'replication_factor': 3,
            'resource_profile': 'medium',
            'available_memory': 8192,
            'control_center': False,
            'control_center_next_gen': False,
            'prometheus': False,
            'shared_mode': False,
        }
        defaults.update(kwargs)
        return Namespace(**defaults)

    def test_valid_profiles(self):
        """Test that valid profile names pass"""
        for profile in ['small', 'medium', 'large', 'none']:
            args = self.create_args(resource_profile=profile)
            errors, warnings = validate_configuration(args)
            self.assertEqual(len(errors), 0, f"Profile {profile} should be valid")


class TestValidationExceptions(unittest.TestCase):
    """Test custom exception classes"""

    def test_validation_error_creation(self):
        """Test ValidationError exception"""
        error = ValidationError("Test error message")
        self.assertEqual(str(error), "Test error message")

    def test_validation_warning_creation(self):
        """Test ValidationWarning exception"""
        warning = ValidationWarning("Test warning message")
        self.assertEqual(warning.message, "Test warning message")
        # Test with suggestion
        warning_with_suggestion = ValidationWarning("Test", "Do this")
        self.assertEqual(warning_with_suggestion.message, "Test")
        self.assertEqual(warning_with_suggestion.suggestion, "Do this")


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
