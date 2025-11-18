import logging
import sys


def get_logger(name, level):
    logger = logging.getLogger(name)
    logging.basicConfig(stream=sys.stdout, level=level)

    return logger
