# bbv

Bbv (for "bare-bones viewer") is a **minimalist data plotter/viewer for the
command line**. Bbv is best suited for a quick look at functional relations
gathered during exploratory data analysis.

Bbv uses stdin as input and must be called from a pipe of shell commands:

```
command_1 | command_2 | ... | bbv
```

The data must be tab-separated, and **there is only one option**, `x`.

Piping your data into `bbv` will produce a line plot column by column.
For example:

![line plot](columns.png)

Piping your data into `bbv x` will produce a scatter plot of pairwise (x, y)
values. For example:

![scatter plot](pairwise.png)

Bbv, being written in POSIX shell and awk, requires only a functioning POSIX
system and does not tie you to any extra toolchain. You can use any lightweight
image viewer as back end, provided it reads the SVG format. Possible candidates
are, in alphabetical order:

- eom (Eye of MATE)
- feh
- imv
- loupe (GNOME Image Viewer)
- pqiv
- sxiv | nsxiv
- viewnior
- vimiv

All of these viewers open SVGs, permit image zooming (+/-), and allow you to use
keyboard arrows for paning. Some of these viewers also accept vim-like shortcuts
(h, j, k, l) for arrows.

## Important

Bbv does not support real-time plotting of a long-term running process. If
dynamic plotting of a data stream is your use case, you will be better served
by [feedgnuplot](https://github.com/dkogan/feedgnuplot).


# Installation

* Download the provided [bbv](bbv) file.

* Make the file executable (`chmod +x bbv`) and put it into your PATH.

* Specify your image back end via the environment variable, `BBV_BACKEND`.

For example, if you want to use [imv](https://sr.ht/~exec64/imv/) as image
viewer, write the following:

```
export BBV_BACKEND='imv'
```

in your `.bashrc` or equivalent.

You can include command-line options in what you specify as bbv's back end.
For example:

```
export BBV_BACKEND='imv -c overlay'
```


# Usage

Typing `bbv` directly in the terminal will print a short help on usage.

Otherwise, usage is from a pipe, `... | bbv [x]`, `x` being optional.

The ranges of the resulting plot are the minima and maxima of your dataset.
While plotting, bbv skips missing values and non-numeric values.

It goes without saying that there are no options for titles, annotations,
legends, custom axes, axis transformations, custom labels, ticks, colors,
styles, plot types, and so on.


# Note on output

The file that `bbv` produces from stdin (and that is opened by your chosen
back end) is saved in your working directory as `tmp_bbv.svg`. This is a
regular SVG file, fully editable in Inkscape (for example).


# License

MIT

