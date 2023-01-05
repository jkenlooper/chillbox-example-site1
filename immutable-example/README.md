# Immutable Make Example

This directory holds the source files that will be processed by the Makefile and
associated *.mk files.

## Updating Generated Files

Run the cookiecutter command again to update any generated files with newer
versions from the [cookiecutter immutable-make](https://github.com/jkenlooper/cookiecutters).

```bash
# From the top level of the project.
cookiecutter --directory immutable-make \
  --overwrite-if-exists \
  --no-input \
  https://github.com/jkenlooper/cookiecutters.git \
  slugname=site1
```
