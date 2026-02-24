"""
Setup script for Kafka Docker Composer

This allows the project to be installed as a Python package.
"""

from setuptools import setup, find_packages
import os

# Read the README file for long description
with open('README.md', 'r', encoding='utf-8') as f:
    long_description = f.read()

# Read version from constants.py
version = '1.0.0'

setup(
    name='kafka-docker-composer',
    version=version,
    author='Pentaho Workshop',
    description='A tool to generate production-ready Apache Kafka clusters using Docker Compose',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/yourusername/kafka-docker-composer',
    packages=find_packages(exclude=['tests', 'tests.*']),
    include_package_data=True,
    install_requires=[
        'Jinja2>=3.1.2',
    ],
    python_requires='>=3.7',
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Intended Audience :: System Administrators',
        'Topic :: Software Development :: Code Generators',
        'Topic :: System :: Distributed Computing',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Operating System :: OS Independent',
    ],
    entry_points={
        'console_scripts': [
            'kafka-docker-composer=kafka_docker_composer:main',
        ],
    },
    package_data={
        'docker-generator': ['templates/*.j2'],
    },
    keywords='kafka docker docker-compose confluent kafka-cluster deployment',
    project_urls={
        'Bug Reports': 'https://github.com/yourusername/kafka-docker-composer/issues',
        'Source': 'https://github.com/yourusername/kafka-docker-composer',
        'Documentation': 'https://github.com/yourusername/kafka-docker-composer/blob/master/README.md',
    },
)
