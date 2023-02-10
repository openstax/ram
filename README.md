# Random Asset Management

![ram](./ram.svg)

This is a place to put things that you want to be avalable on the internet

## Upload

upload works in individual files or directories, internally it uses
`aws s3 sync --delete`, so unspecified files in the directory will be
removed.

```bash
# ./upload [env name] [project][optional-path] [directory to upload]
../ram/upload prod h5p ./h5p-stuff

# with optional path to upload a subset
../ram/upload prod h5p/libraries ./h5p-stuff/librarires
```

the project name must be configured in the ram code and there are (will be)
policies allowing only certain iam roles to upload to project prefixes.

files are then available to be viewed at:

https://ram.openstax.org/[project]/[optional-path]/file.name
