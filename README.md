# `site1`

A Chillbox compatible site.

## Updating Generated Files

Run the cookiecutter command again to update any generated files with newer
versions from the [cookiecutter chillbox-site](https://github.com/jkenlooper/cookiecutters).

```bash
# From the top level of the project.
cookiecutter --directory chillbox-site \
  --overwrite-if-exists \
  --no-input \
  https://github.com/jkenlooper/cookiecutters.git \
  slugname=site1 \
  chillbox_site_directory=.
```
