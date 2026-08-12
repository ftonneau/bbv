#!/bin/sh

# ------------------------------------------------------------

if [ -t 0 ]; then
    cat << EOF
bbv is run from a pipe of shell commands: ... | bbv [x]

Typing 'bbv' alone produces a line plot of your data, column by column: y1, y2,
..., yN. Input row numbers serve implicitly as x values.

Typing 'bbv x' produces a scatter plot of pairwise (x, y) values, specified
along successive data columns: x1, y1, x2, y2, ..., xN, yN.

Data columns must be tab-separated. The output from bbv is a temporary SVG
file in the working directory (tmp.svg), to be opened by the viewer of your
choice. Which program you want to use must be specified in the environment
variable, BBV_BACKEND. For example, with imv as image viewer:

export BBV_BACKEND='imv'

will make imv display your data plot. Viewer options can also be included in
BBV_BACKEND. For example:

export BBV_BACKEND='imv -c overlay'

EOF
    exit 0
fi

if [ -z "$BBV_BACKEND" ]; then
    cat << EOF
bbv error: the BBV_BACKEND environment variable should be set to the image
viewer of your choice. For example, with imv as your image viewer:

export BBV_BACKEND='imv'

EOF
    exit 1
fi

# ------------------------------------------------------------

pairwise=0
[ "$1" = x ] && pairwise=1

awk -v Pairwise=$pairwise '

BEGIN {
    FS = "\t"

    Colors[1] = "black"
    Colors[2] = "red"
    Colors[3] = "blue"
    Colors[4] = "yellow"
    Colors[5] = "gray"
    Colors[6] = "black"
    Colors[7] = "red"
    Colors[8] = "blue"
    Colors[9] = "yellow"
    Colors[10] = "gray"

    Dashes[1] = "none"
    Dashes[2] = "none"
    Dashes[3] = "none"
    Dashes[4] = "none"
    Dashes[5] = "none"
    Dashes[6] = "1, 1"
    Dashes[7] = "1, 1"
    Dashes[8] = "1, 1"
    Dashes[9] = "1, 1"
    Dashes[10] = "1, 1"

    Output = "temp.svg"

    Page_width = 1000
    Page_height = 700

    Background = "white"

    View_x = 200
    View_y = 75
    View_width = Page_width - 1.5 * View_x
    View_height = Page_height - 2 * View_y

    Grid_color = "#cccccc"
    Grid_pen = 1

    Font_size = 18
    Font_family = "sans-serif"
    Label_color = "black"
    Label_hdist = 20
    Label_vdist = Font_size + 15

    Line_width = 3
    Marker_size = 5

    Decimals = 5
    Almost_zero = 1e-10

    Dquote = "\042";
}

NR == 1 {
    Ncols = NF
    if (Pairwise && Ncols % 2 != 0) {
        die("xy plotting requires an even number of columns")
    }
}

{
    if (NF != Ncols) {
        die("number of columns is not constant.")
    }
    if (Pairwise) {
        for (k = 1; k <= NF; k += 2) x_check($k)
        for (k = 2; k <= NF; k += 2) y_check($k)
    }
    else {
        for (k = 1; k <= NF; k += 1) y_check($k)
    }
}

END {
    if (HasDied) exit 2
    if (!Pairwise) {
        Xmin = 1
        Xmax = NR
        x_range = 1
    }
    if (!x_range) die("x range could not be determined")
    if (!y_range) die("y range could not be determined")
}

function die(msg) {
    print "bbv halted: " msg > "/dev/stderr"
    HasDied = 1
    # Before the END block, jump to END; in the END block, exit for good.
    exit
}

function x_check(value) {
    if (!is_num(value)) return
    if (!x_range) {
        Xmin = value
        Xmax = value
        x_range = 1
    }
    else {
        if (value < Xmin) Xmin = value
        if (value > Xmax) Xmax = value
    }
}

function y_check(value) {
    if (!is_num(value)) return
    if (!y_range) {
        Ymin = value
        Ymax = value
        y_range = 1
    }
    else {
        if (value < Ymin) Ymin = value
        if (value > Ymax) Ymax = value
    }
}

function is_num(x) {
    return x == x + 0
}

'

