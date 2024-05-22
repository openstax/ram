# Able Player template and assets

## Template

The template/index.html file is uploaded to ancillaries as a delivery format template. The script urls are hardcoded to RAM production and will need to be changed when uploading to dev or staging ancillaries.

## Building and uploading assets

Run `yarn build` in the able-player repo and then move the following directories and license file into lib:

```
build/
button-icons/
translations/
LICENSE
```

Able Player depends on jQuery and js.cookie, place any updates to those assets into the lib/vendor directory.

Then upload the lib directory to RAM:

```bash
./upload [env] able-player ./projects/able-player/lib
```
