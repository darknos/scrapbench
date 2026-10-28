#!/bin/sh
# @name JSON pretty (jq)
# @group Shell
# @description Reformats with jq; errors show jq's message

# Any command line tool works the same way: text in, text out.
# jq prints its parse error to stderr and exits non-zero, so the banner
# shows the error and the scrap stays as it was.

exec jq .
