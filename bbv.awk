#!/bin/sh

if [ -t 0 ]  && [ "$*" = -h ]; then
    cat << EOF
bbv is run from a pipe: ... | bbv [x]

Typing 'bbv' alone will produce a line plot column by column.
Typing 'bbv x' will produce a pairwise x-y scatter plot. 

Standard input to bbv must be tab-delimited. The output from bbv is saved to
a temporary tmp.svg file in the current directory.

The environment variable, BBV_BACKEND, should contain the shell command used
to display the tmp.svg file. If your image viewer accepts options, they can
be included in the shell command. For example, with img as image viewer:

export BBV_BACKEND='imv -c overlay'

EOF
    exit 0
fi

if [ -t 0 ]; then
    echo 'bbv must be run from a pipe, ... | bbv' >&2
    exit 1
fi



drawing_mode=$1
test -z "$drawing_mode" && drawing_mode=l   # default is a line plot

awk -v Mode="$drawing_mode" '

BEGIN {
    FS = "\t"
    Plotfile = "temp.svg"

    Ncolors = 4
    Color_list = "#2a2222:#154d88:#943b14:#7f7d2d"
    split(Color_list, Colors, ":")

    Ndashes = 2
    Dash_list = "none:8 4"
    split(Dash_list, Dashes, ":")

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

    Ncols = 0
    Nrows = 0

    Xmin = 0
    Xmax = 0
    Ymin = 0
    Ymax = 0

    Xnums_started = 0
    Ynums_started = 0

#   Data: a [Nrows, Ncols] array of values

    Plot_viewer = "imv -c overlay"
}

NR == 1 {
    Ncols = NF
    if (Mode == "s") {
        if (Ncols < 2 || Ncols % 2 != 0) halt("number of columns is not even.")
    }
}

{
    if (NF != Ncols) halt("number of columns is not constant.")
    rownum = NR
    # By default, ranges are computed separately for odd and even columns,
    # interpreted as containing x and y values. This can be changed later.
    for (colnum = 1; colnum <= NF; colnum += 2) {
        input = $colnum
        if (isnum(input)) update_xrange(input)
        Data[rownum, colnum] = input
    }
    for (colnum = 2; colnum <= NF; colnum += 2) {
        input = $colnum
        if (isnum(input)) update_yrange(input)
        Data[rownum, colnum] = input
    }
}

END {
    if (fatal) exit 2
    Nrows = NR
    if (Nrows <= 1) halt("not enough rows.")

    check_ranges()

    open_page()
    set_background()
    print_hgrid()
    print_vgrid()
    print_frame()
    xlabel(Xmin)
    xlabel(Xmax)
    ylabel(Ymin)
    ylabel(Ymax)
    if (Mode == "l") {
        for (colnum = 1; colnum <= Ncols; colnum++) plot_line(colnum)
    }
    else {
        for (colnum = 1; colnum <= Ncols; colnum += 2) plot_scatter(colnum)
    }
    close_page()

    show_plot()
}

function halt(msg) {
    print "Program halted: " msg > "/dev/stderr"
    fatal = 1
    exit    # => in the END block, exit; elsewhere, jump to END
}

function isnum(x) {
    return x == x + 0
}

function update_xrange(input) {
    if (Xnums_started) {
        if (input < Xmin) Xmin = input
        if (input > Xmax) Xmax = input
    }
    else {
        Xmin = input
        Xmax = input
        Xnums_started = 1
    }
}

function update_yrange(input) {
    if (Ynums_started) {
        if (input < Ymin) Ymin = input
        if (input > Ymax) Ymax = input
    }
    else {
        Ymin = input
        Ymax = input
        Ynums_started = 1
    }
}

function check_ranges() {
    if (!Xnums_started || (Ncols > 1 && !Ynums_started)) {
        halt("not enough numbers")
    }
    # In line mode, ranges are recomputed, as all columns are now supposed to
    # contain y values, and x values are row numbers.
    if (Mode == "l") {
        if (Ncols == 1) {
            Ymin = Xmin
            Ymax = Xmax
        }
        else {
            Ymin = Xmin < Ymin ? Xmin : Ymin
            Ymax = Xmax > Ymax ? Xmax : Ymax
        }
        Xmin = 1
        Xmax = Nrows
    }
    if (too_close(Xmin, Xmax)) { Xmin -= 1; Xmax += 1 }
    if (too_close(Ymin, Ymax)) { Ymin -= 1; Ymax += 1 }
}

function too_close(u, v,
    distance) {
    distance = u - v > 0 ? u - v : v - u
    return distance <= Almost_zero
}

function quoted(content) {
    return Dquote content Dquote
}

function open_page() {
    print \
    "<svg xmlns=" quoted("http://www.w3.org/2000/svg"),
    "width=" quoted(Page_width),
    "height=" quoted(Page_height),
    ">" \
    > Plotfile
}

function set_background() {
    print \
    "<rect x=" quoted(0), "y=" quoted(0),
    "width=" quoted("100%"), "height=" quoted("100%"),
    "fill=" quoted(Background), "stroke-width=" quoted("none"),
    "/>" \
    > Plotfile
}

function print_hgrid() {
    for (__ = Ymin; __ <= Ymax; __ += (Ymax - Ymin)/4) {
        print \
        "<path fill=" quoted("none"),
        "stroke=" quoted(Grid_color),
        "stroke-width=" quoted(Grid_pen),
        "d=" Dquote > Plotfile
        printf ("M%f %f ", xcoord(Xmin), ycoord(__)) > Plotfile
        printf ("h %f", View_width) > Plotfile
        print Dquote "\n/>" > Plotfile
    }
}

function print_vgrid() {
    for (__ = Xmin; __ <= Xmax; __ += (Xmax - Xmin)/4) {
        print \
        "<path fill=" quoted("none"),
        "stroke=" quoted(Grid_color),
        "stroke-width=" quoted(Grid_pen),
        "d=" Dquote > Plotfile
        printf ("M%f %f ", xcoord(__), ycoord(Ymin)) > Plotfile
        printf ("v %f", -View_height) > Plotfile
        print Dquote "\n/>" > Plotfile
    }
}

function print_frame() {
    print \
    "<rect x=" quoted(View_x), "y=" quoted(View_y),
    "width=" quoted(View_width), "height=" quoted(View_height),
    "fill=" quoted("none"), "stroke-width=" quoted(Grid_pen),
    "stroke=" quoted(Grid_color),
    "/>" \
    > Plotfile
}

function xlabel(x) {
    print \
    "<text font-size=" quoted(Font_size),
    "font-family=" quoted(Font_family),
    "text-anchor=" quoted("middle"),
    "x=" quoted(xcoord(x)),
    "y=" quoted(ycoord(Ymin) + Label_vdist),
    "fill=" quoted(Label_color) ">" > Plotfile
    print formatted(x) " </text>" > Plotfile
}

function ylabel(y) {
    print \
    "<text font-size=" quoted(Font_size),
    "font-family=" quoted(Font_family),
    "text-anchor=" quoted("end"),
    "x=" quoted(xcoord(Xmin) - Label_hdist),
    "y=" quoted(ycoord(y) + Font_size/3),
    "fill=" quoted(Label_color) ">" > Plotfile
    print formatted(y) " </text>" > Plotfile
}

function formatted(num) {
    return num == int(num) ? num : sprintf("%." Decimals "f", num)
}

function plot_line(colnum,
    data_color, data_dash, x, y, yprev) {

    data_color = Colors[double_select(colnum, Ncolors)]
    data_dash = Dashes[basic_select(colnum, Ndashes)]

    print \
    "<path fill=" quoted("none"),
    "stroke=" quoted(data_color),
    "stroke-dasharray=" quoted(data_dash),
    "stroke-width=" quoted(Line_width),
    "d=" Dquote \
    > Plotfile

    x = 1
    y = Data[1, colnum]
    if (isnum(y)) moveto(x, y)
    for (x = 2; x <= Nrows; x++) {
        yprev = y
        y = Data[x, colnum]
        if (!isnum(yprev) && isnum(y)) moveto(x, y)
        else if (isnum(yprev) && isnum(y)) lineto(x, y)
    }

    print Dquote "\n/>" \
    > Plotfile
}

function plot_scatter(colnum,
    data_color, id, url, rownum, x, y, yprev) {

    data_color = Colors[double_select(colnum, Ncolors)]

    id = "M" colnum
    print \
    "<marker id=" quoted(id) " overflow=" quoted("visible") ">",
    "<circle r=" quoted(Marker_size),
    "fill=" quoted(data_color),
    "stroke=" quoted("none"),
    "stroke-width=" quoted(0),
    "/> </marker>" \
    > Plotfile

    url = "url(#" id ")"
    print \
    "<path fill=" quoted("none"),
    "stroke=" quoted("none"),
    "marker-start=" quoted(url),
    "marker-mid=" quoted(url),
    "marker-end=" quoted(url),
    "d=" Dquote \
    > Plotfile

    for (rownum = 1; rownum <= Nrows; rownum++) {
        x = Data[rownum, colnum]
        y = Data[rownum, colnum + 1]
        if (isnum(x) && isnum(y)) moveto(x, y)
    }

    print Dquote "\n/>" \
    > Plotfile
}

function double_select(number, maximum,
    even) {
    even = number % 2 == 0 ? number : number + 1
    return basic_select(even / 2, maximum)
}

function basic_select(number, maximum,
    modulo) {
    modulo = number % maximum
    return modulo == 0 ? maximum : modulo
}

function moveto(x, y) {
    printf("M%f %f ", xcoord(x), ycoord(y)) > Plotfile
}

function lineto(x, y) {
    printf("L%f %f ", xcoord(x), ycoord(y)) > Plotfile
}

function xcoord(x,
    xnorm) {
    xnorm = (x - Xmin)/(Xmax - Xmin)
    return View_x + xnorm * View_width
}

function ycoord(y,
    ynorm) {
    ynorm = (Ymax - y)/(Ymax - Ymin)
    return View_y + ynorm * View_height
}

function close_page() {
    print "</svg>" > Plotfile
}

function show_plot() {
    system(Plot_viewer " temp.svg &")
}

'

