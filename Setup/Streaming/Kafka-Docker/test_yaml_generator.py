"""
Kafka Docker Composer - Unit Tests

This module contains unit tests for the DockerComposeGenerator class.
Currently focuses on testing the rack assignment logic for distributing
brokers across multiple racks.

Usage:
    python -m unittest test_yaml_generator.py
    or
    python -m pytest test_yaml_generator.py
"""

import unittest

from kafka_docker_composer import DockerComposeGenerator


class TestYamlGenerator(unittest.TestCase):
    """
    Base test class for YAML generator tests.

    This serves as a parent class for all DockerComposeGenerator tests,
    providing common setup and teardown functionality.
    """
    def setUp(self):
        """Set up test fixtures before each test method."""
        pass


class TestNextRack(TestYamlGenerator):
    """
    Test cases for the next_rack() static method.

    The next_rack() method implements round-robin rack assignment
    for distributing Kafka brokers across multiple racks to ensure
    fault tolerance at the rack level.
    """

    def testSimpleAdd(self):
        """
        Test basic rack increment.

        Given: rack=0, total_racks=2
        When: next_rack() is called
        Then: Should return 1 (next rack in sequence)
        """
        rack = 0
        next = DockerComposeGenerator.next_rack(rack, 2)
        self.assertEqual(next, 1)

    def testOne(self):
        """
        Test single rack scenario.

        Given: rack=0, total_racks=1
        When: next_rack() is called
        Then: Should return 0 (wraps back to only available rack)
        """
        rack = 0
        next = DockerComposeGenerator.next_rack(rack, 1)
        self.assertEqual(next, 0)

    def testTotalRollover(self):
        """
        Test rack rollover at the end of rack list.

        Given: rack=1 (last rack), total_racks=2
        When: next_rack() is called
        Then: Should return 0 (wraps back to first rack)
        """
        rack = 1
        next = DockerComposeGenerator.next_rack(rack, 2)
        self.assertEqual(next, 0)
