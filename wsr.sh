

_wsr_session=`mktemp -td "wsr.$$.XXXXXXXX"`
_wsr_counter=0

wsr_load_session() {
    cp "$1"/*.data $_wsr_session/
}

wsr_save_session() {
    cp $_wsr_session/*.data "$1"/
}

wsr_back() {
    if [ $_wsr_counter -gt 0 ]; then
        _wsr_counter=`expr $_wsr_counter - 1`;
    else
        return 1
    fi
}

wsr_forward() {
    local try_counter
    try_counter=`expr $_wsr_counter + 1`
    if [ -f `_wsr_file $try_counter`.url ]
        _wsr_counter=$try_counter
    else
        return 1
    fi
}

wsr_reload() {
    local addr url
    url=`cat $addr.url`
    _wsr_request "$url" $_wsr_counter
    return $?
}

_wsr_file() {
    printf "%s/page%04d" $_wsr_session $1
}

_wsr_build_options() {
    local lower referer here
    here=`_wsr_file $1`
    echo -n -- -f -L -D $2.header -o $2.body -c $2.cookie
    if [ $1 -gt 0 ]; then
        lower=`expr $1 - 1`
        lower=`_wsr_file lower`
        echo -- -e "`cat $lower.url`;auto"
	else
		echo
	fi
}

_wsr_request() {
    local extra_info http_code effective_url content_type encoding
    extra_info=`curl -f -L -D $2.header -o $2.body -c $2.cookie -w "%http_code\n%url_effective\n%content_type" "$1"`
    if [ $? -ne 0 ]; then
        rm $2.*
        return -1
    fi
    http_code=`echo "$extra_info"|head -n1`
    effective_url=`echo "$extra_info"|tail -n+1|head -n1|tee $2.url`
    content_type=`echo "$extra_info"|tail -n+2|head -n1`
    encoding=`cat $2.enc`
    encoding=`_wsr_get_encoding $2 "$encoding"|head -n1|tee $2.enc`
    if [ "$encoding" != "x-user-defined" ]; then
        iconv -f "$encoding" -t 'utf-8' $2.body
    fi
}

_wsr_enc_bom_utf16le = `printf \xef\xff`
_wsr_enc_bom_utf16be = `printf \xff\xef`
_wsr_enc_bom_utf8 = `printf \xef\xbb\xbf`

_wsr_detect_encoding() {
    local headerenc bodyenc
    # BOM
    case `head -c3 $1.body` in
        $_wsr_enc_bom_utf16le*) echo utf-16le; return 0;
            ;;
        $_wsr_enc_bom_utf16be*) echo utf-16be; return 0;
            ;;
        $_wsr_enc_bom_utf8*) echo utf-8; return 0;
            ;;
    esac
    # Let's ignore backslash escapes, for we have a life.
    headerenc=`cat $1.header | sed -r -n "/^Content-type:/ s/.*charset\s*=\s*('([^']*)'|\"([^\"]*)\"|([^ \n\t\r\f;]*)).*/\2\3\4/g p"|head -n1`
    if [ "$headerenc" ]; then
        echo "$headerenc"
        return 0
    fi
    cat $2.body | html-encoding-prescan
    if which enca >/dev/null; then
        enca -i $1.body
    fi
    if which chardet >/dev/null; then
        chardet $1.body | awk '{print $2}'
    fi
};

_wsr_get_encoding() {
    _wsr_detect_encoding "$1" | tr -cd "[:alnum:]-" |
    while read x; do
        _wsr_encoding_table() | awk "/^$x /"' { print $2; }';
    done |
    while read x; do
        if [ "$x" == "x-user-defined" ]; then
            print "$x";
        elif iconv -f "$x//IGNORE" -t "$x//IGNORE" >/dev/null </dev/null 2>/dev/null; then
            echo "$x"
        fi
    done
    if [ "$2" ]; then
        echo "$2"
    else
        echo utf-8
    fi
}


