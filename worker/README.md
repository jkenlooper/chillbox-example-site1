# `site1` worker

Python worker that is compatible with Chillbox site.

## Updating Generated Files

Run the cookiecutter command again to update any generated files with newer
versions from the [cookiecutter python-worker](https://github.com/jkenlooper/cookiecutters).

```bash
# From the top level of the project.
cookiecutter --directory python-worker \
  --overwrite-if-exists \
  https://github.com/jkenlooper/cookiecutters.git \
  slugname=site1 \
  project_slug=worker
```
