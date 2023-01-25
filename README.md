# Site1

A [Chillbox] compatible site.

## Maintenance

Where possible, an upkeep comment has been added to various parts of the source
code. These are known areas that will require updates over time to reduce
software rot. The upkeep comment follows this pattern to make it easier for
commands like grep to find these comments.

Example UPKEEP comment has at least a 'due:' or 'label:' or 'interval:' value
surrounded by double quotes (").
````
Example-> # UPKEEP due: "2022-12-14" label: "Llama Pie" interval: "+4 months"
````

The grep command to find all upkeep comments with their line numbers.
```bash
# Search for UPKEEP comments.
grep -r -n -E "^\W+UPKEEP\W+(due:\W?\".*?\"|label:\W?\".*?\"|interval:\W?\".*?\")" .

# Or
docker run --rm \
  --mount "type=bind,src=$PWD,dst=/tmp/upkeep,readonly=true" \
  --workdir=/tmp/upkeep \
  alpine \
  grep -r -n -E "^\W+UPKEEP\W+(due:\W?\".*?\"|label:\W?\".*?\"|interval:\W?\".*?\")" .

# Or show only past due UPKEEP comments.
make upkeep
```

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
  site_name="Site1" \
  local_app_port=38010 \
  chillbox_site_directory=.
```


[Chillbox]: https://github.com/jkenlooper/chillbox
