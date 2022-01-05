#!/usr/bin/env bash

stow -R . 2>&1 | grep -v "BUG in find_stowed_path"
