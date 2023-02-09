# Random Asset Management

![ram](./ram.svg)

This is a place to put things that you want to be avalable on the internet

## Upload

```bash
# ./upload [env name] [project] [directory to upload]
../ram/upload prod h5p ./libraries
```

the project name must be configured in the ram code and there are (will be)
policies allowing only certain iam roles to upload to project prefixes.

files are then available to be viewed at:

https://ram.openstax.org/[project]/file.name
