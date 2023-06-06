# `site1` api

Python service that is compatible with Chillbox site.

## Updating Generated Files

Run the cookiecutter command again to update any generated files with newer
versions from the [cookiecutter python-service](https://github.com/jkenlooper/cookiecutters).

```bash
# From the top level of the project.
cookiecutter --directory python-service \
  --overwrite-if-exists \
  https://github.com/jkenlooper/cookiecutters.git \
  slugname=site1 \
  project_slug=api \
  project_port=38013
```
