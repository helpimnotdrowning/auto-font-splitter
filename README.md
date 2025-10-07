This script requires [my fork of font-splitter](https://github.com/helpimnotdrowning/font-splitter) *built as* `helpimnotdrowning/font-splitter`
You can do this with `sudo docker build -t helpimnotdrowning/font-splitter .` within the cloned directory.

Usage:

```
split -Source [file or directory] -OutputDirectory [directory] -CssFontPath [format string]
```

* `-Source` is either a woff2 file or a directory of woff2 files
* `-OutputDirectory` is the destination of the generated files
* `-CssFontPath` is the file path used in the generated CSS file of where the font will be accesed from. Write `<XX>` and it will be replaced with the font's name.

ex.
```pwsh
split -Source ./src -OutputDirectory ./out -CssFontPath /font/<XX>
```
will read all woff2 files from `./src`, put the generated fonts in `./out` (where each font gets a subdirectory), with the `url()` in the generated CSS files being `url(/font/<font name>/<font file name>.woff2)`.

---

This project is licensed under the GNU GPLv3. You can see the license at
[LICENSE.md](LICENSE.md)

`split.ps1` uses a translation table from fontconfig weights to CSS weights that
comes from Google's Skia code; its use is licenced under Google's Modified
BSD/"BSD-3" terms (at least I think so). You can see the license, copyright
notice, and disclaimer at [LICENSE.google.md](LICENSE.google.md)
