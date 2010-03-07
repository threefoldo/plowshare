#!/bin/bash
#
# This file is part of Plowshare.
#
# Plowshare is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Plowshare is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Plowshare.  If not, see <http://www.gnu.org/licenses/>.
#

MODULE_MEDIAFIRE_REGEXP_URL="http://\(www\.\)\?mediafire.com/"
MODULE_MEDIAFIRE_DOWNLOAD_OPTIONS=""
MODULE_MEDIAFIRE_UPLOAD_OPTIONS=
MODULE_MEDIAFIRE_DOWNLOAD_CONTINUE=no

# Output a mediafire file download URL
#
# meadifire_download URL
#
mediafire_download() {
    set -e
    eval "$(process_options mediafire "$MODULE_MEDIAFIRE_DOWNLOAD_OPTIONS" "$@")"

    URL=$1
    COOKIESFILE=$(create_tempfile)

    PAGE=$(curl -c $COOKIESFILE "$URL" | sed "s/>/>\n/g")
    COOKIES=$(< $COOKIESFILE)
    rm -f $COOKIESFILE
    
    echo "$PAGE" | grep -qi "Invalid or Deleted File" && 
        { error "invalid or deleted file"; return 254; }
    if test "$CHECK"; then
        match 'class="download_file_title"' "$PAGE" && return 255 || return 1
    fi
    FILE_URL=$(get_ofuscated_link "$PAGE" "$COOKIES") ||
        { error "error running Javascript code"; return 1; }
    
    echo "$FILE_URL"
}

get_ofuscated_link() {
    local PAGE=$1
    local COOKIES=$2
    BASE_URL="http://www.mediafire.com"
    
    FUNCTIONS=$(echo "$PAGE" | grep -o "function [[:alnum:]]\+[[:space:]]*(qk" | 
                awk '{print $2}' | cut -d"(" -f1 | xargs)
    test "$FUNCTIONS" ||
        { error "get_ofuscated_links: error getting JS functions"; return 1; }
    JSCODE=$(echo "$PAGE" | sed "s/;/;\n/g" | grep 'Eo[[:space:]]*();' -A6 | tail -n+2)
    test "$JSCODE" ||
        { error "get_ofuscated_links: error getting JS code"; return 1; }
    JS_CALL=$({
        for FUNCTION in $FUNCTIONS; do 
            echo "function $FUNCTION(qk, pk, r) { 
                  print('$FUNCTION' + ',' + qk + ',' + pk + ',' + r); }"
        done
        echo $JSCODE
    } | js)
    IFS="," read FUNCTION QK PK R < <(echo "$JS_CALL" | tr -d "'")
    debug "function: $FUNCTION"
    JS_URL="$BASE_URL/dynamic/download.php?qk=$QK&pk=$PK&r=$R"
    debug "Javascript URL: $JS_URL"
    DIVID=$(echo "$PAGE" | sed "s/;/;\n/g" | grep "function $FUNCTION" -A10 | 
            parse innerHTML "('\([^']*\)'")
    debug "divid: $DIVID"
    JS_CODE=$(curl -b <(echo "$COOKIES") "$JS_URL")
    {
        echo "
        d = {'innerHTML': ''};
        parent = {
        document: {'getElementById': function(x) { 
            print(x); 
            return d; 
          } 
        },
        };"
        echo "$JS_CODE" | sed -n "2p" | 
            sed "s/eval(\([[:alnum:]]*\))/eval(\1); print(d.innerHTML);/g"
        echo "dz();"
    } | js | parse "'$DIVID'" 'href="\(.*\)"' 
}
