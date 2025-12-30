#!/bin/bash

find "./archives" -maxdepth 1 -name "*.arch" -type f -exec basename {} \; | sort

