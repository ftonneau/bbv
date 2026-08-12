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
    Decimals = 5
    Almost_zero = 1e-10
    FontSize = 20
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

    file = "tmp.svg"

    page_w = 1350
    page_h = 800
    side_w = 200
    grid_w = 4 * 200
    grid_h = 4 * 150
    grid_x = 400
    grid_y = 100
    offset = 15
    white = "#ffffff"
    light_gray = "#e5e5e5"
    mid_gray = "#aaaaaa"

    print("<svg xmlns=" q("http://www.w3.org/2000/svg"),
          "width=" q(page_w), "height=" q(page_h),
          ">") > file
    fill_rect(0, 0, page_w, page_h, white)
    fill_rect(0, 0, side_w, page_h, light_gray)

    for (k = 0; k <= 4; k++) add_line(grid_x + k * grid_w/4, grid_y, 0, grid_h)
    for (k = 0; k <= 4; k++) add_line(grid_x, grid_y + k * grid_h/4, grid_w, 0)

    add_label(grid_x, grid_y + grid_h + 2 * offset, Xmin, "middle")
    add_label(grid_x + grid_w, grid_y + grid_h + 2 * offset, Xmax, "middle")
    add_label(grid_x - offset, grid_y, Ymax, "end")
    add_label(grid_x - offset, grid_y + grid_h, Ymin, "end")

    print("</svg>") > file
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

function q(text) {
    return "\042" text "\042"
}

function fill_rect(x, y, w, h, color) {
    print("<rect x=" q(x),
    "y=" q(y),
    "width=" q(w),
    "height=" q(h),
    "fill=" q(color),
    "stroke-width=" q(0),
    "/>") > file
}

function add_line(x, y, dx, dy) {
    print("<line x1=" q(x),
    "y1=" q(y),
    "x2=" q(x + dx),
    "y2=" q(y + dy),
    "stroke=" q(mid_gray),
    "stroke-width=" q(1),
    "/>") > file
}

function add_label(x, y, num, anchor) {
    label = int(num) == num ? num : sprintf("%." Decimals "f", num)
    print("<text font-size=" q(FontSize),
    "font-family=" q("sans-serif"),
    "text-anchor=" q(anchor),
    "x=" q(x),
    "y=" q(y),
    "fill=" q("black"),
    ">" label "</text>") > file
}

'

