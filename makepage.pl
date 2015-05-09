#!/bin/bash

# make_page - A script to produce an HTML file

title="System infomrtion for"

cat <<- _EOF_
    <HTML>
    <HEAD>
        <TITLE>
        $title $HOSTNAME "its done!"
        </TITLE>
    </HEAD>

    <BODY>
    <H1>$title $HOSTNAME "hopefully it finished!"</H1>
    </BODY>
    </HTML>
_EOF_
