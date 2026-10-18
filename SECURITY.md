# Security policy

MLZ UI runs inside World of Warcraft's Lua sandbox. It can't read or write files outside its own saved variables,
and it doesn't use the network. The parts that handle outside input are the import strings (`/mlz import`) and the
settings it writes for other addons.

## Supported versions

Only the latest release gets fixes.

## Reporting a problem

If you find something that could harm a player (for example an import string that breaks their saved settings
or runs code), please don't open a public issue. Report it privately through
[GitHub's private vulnerability reporting](https://github.com/martinzachariassen/MLZ_UI/security/advisories/new).

Include the steps to reproduce it and, if you can, the string or saved variables involved. You will get an answer
within a week.
