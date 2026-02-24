"""
Logging Module for Kafka Docker Composer

This module provides a centralized logging configuration for the application.
It supports different log levels, colored output, and optional file logging.

Features:
- Colored console output (ANSI codes)
- Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- File logging with detailed format
- TTY detection for automatic color disabling
- Configurable verbosity

Usage:
    from logger import setup_logging, get_logger

    # Setup logging at application start
    logger = setup_logging(verbose=True, log_file='app.log')

    # Get logger in modules
    logger = get_logger(__name__)
    logger.info("Starting process...")
    logger.debug("Debug information")
    logger.warning("Warning message")
    logger.error("Error occurred")
"""

import logging
import sys
from typing import Optional


class ColoredFormatter(logging.Formatter):
    """
    Custom log formatter that adds ANSI color codes to log messages.

    This formatter enhances console readability by coloring log messages
    based on their severity level. Colors are only applied when outputting
    to a TTY (terminal), not when piping to a file or other process.

    Color Scheme:
        DEBUG    - Cyan     (detailed diagnostic information)
        INFO     - Green    (normal operational messages)
        WARNING  - Yellow   (warning messages, potential issues)
        ERROR    - Red      (error messages, failures)
        CRITICAL - Magenta  (critical failures requiring immediate attention)

    Thread Safety:
        This formatter is thread-safe. The levelname is restored after
        formatting to prevent cross-contamination between log records.
    """

    # ANSI escape codes for terminal colors
    # These work on Unix/Linux/Mac terminals and Windows 10+ terminals
    COLORS = {
        'DEBUG': '\033[36m',      # Cyan - diagnostic information
        'INFO': '\033[32m',       # Green - normal operation
        'WARNING': '\033[33m',    # Yellow - warnings
        'ERROR': '\033[31m',      # Red - errors
        'CRITICAL': '\033[35m',   # Magenta - critical issues
        'RESET': '\033[0m'        # Reset to default color
    }

    def format(self, record):
        """
        Format the log record with appropriate color codes.

        This method wraps the log level name with ANSI color codes before
        formatting, then resets the levelname to avoid side effects.

        Args:
            record: LogRecord object containing log information

        Returns:
            str: Formatted log message with color codes
        """
        # Save original levelname to restore later (thread safety)
        levelname = record.levelname

        # Add color codes around the level name if color is defined
        if levelname in self.COLORS:
            # Wrap levelname with color start and reset codes
            colored_level = f"{self.COLORS[levelname]}{levelname}{self.COLORS['RESET']}"
            record.levelname = colored_level

        # Call parent formatter to apply the format string
        result = super().format(record)

        # Restore original levelname for next use
        # This prevents the colored version from leaking to other handlers
        record.levelname = levelname

        return result


def setup_logging(verbose: bool = False, log_file: Optional[str] = None, color: bool = True) -> logging.Logger:
    """
    Configure and initialize the logging system for the application.

    This function sets up a comprehensive logging configuration with both
    console and optional file output. It should be called once at application
    startup before any logging occurs.

    Logging Levels:
        - verbose=False: INFO level (normal operation)
        - verbose=True:  DEBUG level (detailed diagnostic output)

    Console Output:
        - Colored output (if TTY and color=True): Simple format for readability
        - Non-colored output: Timestamped format for parsing

    File Output:
        - Always DEBUG level (captures everything)
        - Includes timestamp, module name, filename, and line number
        - Useful for troubleshooting and audit trails

    Args:
        verbose (bool): Enable DEBUG level logging. Default is INFO level.
        log_file (Optional[str]): Path to log file. If None, no file logging.
        color (bool): Enable colored console output. Auto-disabled for non-TTY.

    Returns:
        logging.Logger: Configured root logger instance

    Example:
        # Basic usage (INFO level, colored console)
        logger = setup_logging()

        # Verbose mode with file logging
        logger = setup_logging(verbose=True, log_file='debug.log')

        # No colors (for CI/CD pipelines)
        logger = setup_logging(color=False)

    Note:
        This function clears existing handlers to avoid duplicate logging
        if called multiple times.
    """
    # ========== Determine Log Level ==========
    # DEBUG shows all messages, INFO shows normal operations and above
    level = logging.DEBUG if verbose else logging.INFO

    # ========== Create Root Logger ==========
    # Use a named logger for the application namespace
    logger = logging.getLogger('kafka_docker_composer')
    logger.setLevel(level)  # Set minimum level the logger will process

    # ========== Clear Existing Handlers ==========
    # Remove any previously configured handlers to avoid duplicates
    # This is important if setup_logging() is called multiple times
    logger.handlers.clear()

    # ========== Console Handler Configuration ==========
    # Stream handler writes to stdout (not stderr) for normal output
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)  # Console follows the same level as logger

    # ========== Choose Console Format ==========
    # Different formats for colored vs non-colored output
    if color and sys.stdout.isatty():
        # Colored format: Simple and clean for terminal viewing
        # sys.stdout.isatty() returns True only for actual terminals
        # This prevents ANSI codes from appearing in piped output
        console_format = '%(levelname)s: %(message)s'
        console_formatter = ColoredFormatter(console_format)
    else:
        # Non-colored format: Includes timestamp for logging systems
        # Used when output is redirected or color is disabled
        console_format = '%(asctime)s - %(levelname)s - %(message)s'
        console_formatter = logging.Formatter(console_format)

    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # ========== File Handler Configuration (Optional) ==========
    # File logging captures everything (DEBUG level) regardless of console level
    if log_file:
        try:
            # Create file handler (appends to existing file)
            file_handler = logging.FileHandler(log_file)

            # Always use DEBUG level for file to capture maximum detail
            file_handler.setLevel(logging.DEBUG)

            # Detailed format for file logging includes:
            # - Timestamp: When the event occurred
            # - Logger name: Which module logged it
            # - Level: Severity of the message
            # - Location: Filename and line number for debugging
            # - Message: The actual log message
            file_format = '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s'
            file_formatter = logging.Formatter(file_format)

            file_handler.setFormatter(file_formatter)
            logger.addHandler(file_handler)

        except (IOError, PermissionError) as e:
            # If file logging fails, warn the user but continue
            logger.warning(f"Could not create log file {log_file}: {e}")

    return logger


def get_logger(name: str = 'kafka_docker_composer') -> logging.Logger:
    """
    Get a logger instance for a specific module or component.

    This function returns a logger from Python's logging hierarchy.
    It should be called in each module that needs logging capability.

    Logger Hierarchy:
        If the name contains dots (e.g., 'kafka_docker_composer.broker'),
        Python creates a hierarchical relationship where:
        - Parent logger: 'kafka_docker_composer'
        - Child logger: 'kafka_docker_composer.broker'

    Child loggers inherit configuration from parent loggers.

    Args:
        name (str): Logger name, typically __name__ to use module name

    Returns:
        logging.Logger: Logger instance for the specified name

    Example:
        # In a module file
        from logger import get_logger
        logger = get_logger(__name__)

        logger.info("Module initialized")
        logger.debug(f"Configuration: {config}")

    Best Practice:
        Use get_logger(__name__) at the module level to automatically
        create hierarchical loggers that inherit the root configuration.
    """
    return logging.getLogger(name)
