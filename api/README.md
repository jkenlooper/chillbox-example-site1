# `site1` api

Flask service that is compatible with chillbox site.

## Updating Generated Files

Run the cookiecutter command again to update any generated files with newer
versions from the [cookiecutter flask-service](https://github.com/jkenlooper/cookiecutters).

```bash
# From the top level of the project.
cookiecutter --directory flask-service \
  --overwrite-if-exists \
  https://github.com/jkenlooper/cookiecutters.git \
  slugname=site1 \
  project_slug=api \
  project_port=38013
```
