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

rm tmp.svg 2>/dev/null

pairwise=0
[ "$1" = x ] && pairwise=1

awk -v Pairwise=$pairwise ' # begin awk

BEGIN {
    FS = "\t"
    # Basic display parameters.
    Decimals = 5
    FontSize = 20
    Line_width = 3
    Dot_radius = 6
    Dashes = "5, 3"
    Colors[1] = "#303030"
    Colors[2] = "#b01010"
    Colors[3] = "#137099"
    Colors[4] = "#806b10"
    Colors[5] = "#730037"
    Colors[6] = "#707070"
    Ncolors = 6
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
    # Determine x and y ranges.
    if (Pairwise) {
        for (k = 1; k <= NF; k += 2) x_check($k)
        for (k = 2; k <= NF; k += 2) y_check($k)
    }
    else {
        for (k = 1; k <= NF; k += 1) y_check($k)
    }
    # Store data for later plotting.
    for (k = 1; k <= NF; k++) {
        Data[NR, k] = $k
    }
}

END {
    if (HasDied) exit
    Nrows = NR
    if (!Pairwise) {
        Xmin = 1
        Xmax = Nrows
        x_range = 1
    }
    if (!x_range) die("x range could not be determined")
    if (!y_range) die("y range could not be determined")

    file = "tmp.svg"

    page_w = 1300
    page_h = 800
    grid_w = 4 * 200
    grid_h = 4 * 150
    grid_x = 400
    grid_y = 100
    h_offset = 15
    v_offset = 25
    key_x = 50
    key_y = 40
    key_tab = 80
    key_step = 40
    text_dy = int(FontSize / 3)
    page_white = "#fffff5"
    grid_gray = "#aaaaaa"
    text_color = "black"

    print("<svg xmlns=" q("http://www.w3.org/2000/svg"),
    "width=" q(page_w), "height=" q(page_h),
    ">",
    "<rect x=" q(0), "y=" q(0), "width=" q(page_w), "height=" q(page_h),
    "fill=" q(page_white), "stroke-width=" q(0),
    "/>") > file

    for (k = 0; k <= 4; k++) add_hair(grid_x + k * grid_w/4, grid_y, 0, grid_h)
    for (k = 0; k <= 4; k++) add_hair(grid_x, grid_y + k * grid_h/4, grid_w, 0)

    add_label(grid_x, grid_y + grid_h + v_offset, Xmin, "middle")
    add_label(grid_x + grid_w, grid_y + grid_h + v_offset, Xmax, "middle")
    add_label(grid_x - h_offset, grid_y, Ymax, "end")
    add_label(grid_x - h_offset, grid_y + grid_h, Ymin, "end")

    if (Pairwise) {
        for (k = 1; k <= Ncols; k += 2) plot_pairs(k)
     }
    else  {
        for (k = 1; k <= Ncols; k++) plot_values(k)
    }

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

function add_hair(x, y, dx, dy) {
    print("<line x1=" q(x),
    "y1=" q(y),
    "x2=" q(x + dx),
    "y2=" q(y + dy),
    "stroke=" q(grid_gray),
    "stroke-width=" q(1),
    "/>") > file
}

function add_label(x, y, num, anchor) {
    label = int(num) == num ? num : sprintf("%." Decimals "f", num)
    print("<text font-size=" q(FontSize),
    "font-family=" q("sans-serif"),
    "text-anchor=" q(anchor),
    "x=" q(x),
    "y=" q(y + text_dy) ,
    "fill=" q(text_color),
    ">" label "</text>") > file
}

function plot_pairs(col,
    marker_id, marker_ref, color_picker,
    row, x, y) {
    marker_id = "M" col
    marker_ref = "url(#" marker_id ")"
    color_picker = modulo((col + 1) / 2, Ncolors)

    print("<marker id=" q(marker_id),
    "overflow=\"visible\">",
    "<circle r=" q(Dot_radius),
    "fill=" q(Colors[color_picker]),
    "stroke-width=" q("none"),
    "/> </marker>") > file

    # Draw scatter plot.
    print("<path fill=" q("none"),
    "stroke=" q("none"),
    "marker-start=" q(marker_ref),
    "marker-mid=" q(marker_ref),
    "marker-end=" q(marker_ref),
    "d=\"") > file
    for (row = 1; row <= Nrows; row++) {
        x = Data[row, col]
        y = Data[row, col + 1]
        if (is_num(x) && is_num(y)) printf("M%f %f ", xc(x), yc(y)) > file
    }
    print("\"/>") > file

    # Add key to legend.
    print("<path marker-start=" q(marker_ref),
    "d=" q("M" key_x "," key_y " Z"),
    "/>",
    "<text font-size=" q(FontSize),
    "font-family=" q("sans-serif"),
    "x=" q(key_tab),
    "y=" q(key_y + text_dy),
    "fill=" q(text_color),
    ">" col ":" col+1,
    "</text>") > file

    key_y += key_step
}

function plot_values(col,
    color_picker, dash_picker, pattern,
    row, y, yprev) {
    color_picker = modulo(col, Ncolors)
    dash_picker = modulo(col, Ncolors * 2)
    pattern = dash_picker <= Ncolors ? "none" : Dashes

    # Draw line plot.
    print("<path fill=" q("none"),
    "stroke=" q(Colors[color_picker]),
    "stroke-dasharray=" q(pattern),
    "stroke-linejoin=" q("round"),
    "stroke-width=" q(Line_width),
    "d=\"") > file
    y = Data[1, col]
    if (is_num(y)) printf("M%f %f ", xc(1), yc(y)) > file
    for (row = 2; row <= Nrows; row++) {
        yprev = y
        y = Data[row, col]
        if (!is_num(yprev) && is_num(y)) printf("M%f %f ", xc(row), yc(y)) > file
        else if (is_num(yprev) && is_num(y)) printf("L%f %f ", xc(row), yc(y)) > file
    }
    print("\"/>") > file

    # Add key to legend.
    print("<path fill=" q("none"),
    "stroke=" q(Colors[color_picker]),
    "stroke-dasharray=" q(pattern),
    "stroke-width=" q(Line_width),
    "d=" q("M" key_x - Dot_radius * 2"," key_y " h" Dot_radius * 4),
    "/>",
    "<text font-size=" q(FontSize),
    "font-family=" q("sans-serif"),
    "x=" q(key_tab),
    "y=" q(key_y + text_dy),
    "fill=" q(text_color),
    ">" col,
    "</text>") > file

    key_y += key_step
}

function modulo(k, kmax,
    remain) {
    remain = k % kmax
    if (remain == 0) remain = kmax
    # => return wrapped value from 1 to kmax
    return remain
}

function xc(x) {
    return grid_x + (x - Xmin)/(Xmax - Xmin) * grid_w
}

function yc(y) {
    return grid_y + grid_h - (y - Ymin)/(Ymax - Ymin) * grid_h
}

' # end awk

if [ -f tmp.svg ]; then
    $BBV_BACKEND tmp.svg &
else
    exit 1
fi

