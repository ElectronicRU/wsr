#!sh

_wsr_session=`mktemp -td "wsr.$$.XXXXXXXX"`
trap _wsr_cleanup EXIT
_wsr_counter=0

_wsr_cleanup () {
	rm -r "$_wsr_session"
}

wsr_load_session() {
    cp "$1"/*.data "$_wsr_session/"
}

wsr_save_session() {
    cp "$_wsr_session/"*.data "$1"/
}

wsr_back() {
    if [ $_wsr_counter -gt 1 ]; then
        _wsr_counter=`expr $_wsr_counter - 1`;
    else
        return 1
    fi
}

wsr_forward() {
    local try_counter
    try_counter=`expr $_wsr_counter + 1`
    if [ -f `_wsr_file $try_counter`.url ]; then
        _wsr_counter=$try_counter
    else
        return 1
    fi
}

wsr_go() {
	_wsr_counter=`expr $_wsr_counter + 1`
	_wsr_request "$1" $_wsr_counter
}

wsr_reload() {
    local addr url
	addr=`_wsr_file $_wsr_counter`
    url=`cat $addr.url`
    _wsr_request "$url" $_wsr_counter
    return $?
}

wsr_get_body() {
	cat `_wsr_file $_wsr_counter`.body || echo >&2 "Body not fetched; something bad happened."
}

_wsr_file() {
    printf "%s/page%04d" $_wsr_session $1
}

_wsr_curl_options() {
    local lower referer here
    here=`_wsr_file $1`
    echo -n   -f -L -D $here.header -o $here.body -c $here.cookie
    if [ $1 -gt 1 ]; then
        lower=`expr $1 - 1`
        lower=`_wsr_file $lower`
        echo " -e" "`cat $lower.url`;auto"
	else
		echo
	fi
}

_wsr_request() {
    local extra_info http_code effective_url content_type encoding filename
	filename=`_wsr_file $2`
	command="curl `_wsr_curl_options $2` -w %{http_code}\\\n%{url_effective}\\\\n%{content_type} \"$1\""
    extra_info=`eval "$command"`
    if [ $? -ne 0 ]; then
        rm "$filename.*"
        return 255
    fi
    http_code=`echo "$extra_info"|head -n1`
    effective_url=`echo "$extra_info"|tail -n+2|head -n1|tee "$filename.url"`
    content_type=`echo "$extra_info"|tail -n+3|head -n1`
    encoding=`cat $2.enc 2>/dev/null`
    encoding=`_wsr_get_encoding "$filename" "$content_type" "$encoding"|head -n1|tee "$filename.enc"`
    if [ "$encoding" != "x-user-defined" ]; then
        iconv -f "$encoding" -t 'utf-8' "$filename.body" -o "$filename.body"
    fi
}

_wsr_enc_bom_utf16le=`printf "\\xef\\xff"`
_wsr_enc_bom_utf16be=`printf "\\xff\\xef"`
_wsr_enc_bom_utf8=`printf "\\xef\\xbb\\xbf"`

_wsr_detect_encoding() {
    local headerenc bodyenc
    # BOM
    case `head -c3 "$1.body"` in
        $_wsr_enc_bom_utf16le*) echo utf-16le; return 0;
            ;;
        $_wsr_enc_bom_utf16be*) echo utf-16be; return 0;
            ;;
        $_wsr_enc_bom_utf8*) echo utf-8; return 0;
            ;;
    esac
    # Let's ignore backslash escapes, for we have a life.
    headerenc=`echo "$2" | sed -r -n "/charset/ s/.*charset\s*=\s*('([^']*)'|\"([^\"]*)\"|([^ \n\t\r\f;]*)).*/\2\3\4/g p"|head -n1`
    if [ "$headerenc" ]; then
        echo "$headerenc"
        return 0
    fi
	if which html-encoding-prescan >/dev/null; then
		html-encoding-prescan "$1.body"
	fi
    if which enca >/dev/null; then
        enca -i "$1.body"
    fi
    if which chardet >/dev/null; then
        chardet $1.body | awk '{print $2}'
    fi
};

_wsr_get_encoding() {
    _wsr_detect_encoding "$1" "$2" | # tr -cd "[:alnum:]-" |
	while read x; do
		tabled=`_wsr_encoding_table | awk ' { if ($2 == '"\"$x\""') print $1; }'`
		if [ -z "$tabled" ]; then echo "$x"; else echo "$tabled"; fi
    done |
    while read x; do
        if [ "$x" = "x-user-defined" ]; then
            echo "$x"
        elif iconv -f "$x//IGNORE" -t "$x//IGNORE" >/dev/null </dev/null 2>/dev/null; then
            echo "$x"
        fi
    done
    if [ "$3" ]; then
        echo "$3"
    else
        echo utf-8
    fi
}

# this is the default (empty) table, real one is constructed by makefile

_wsr_encoding_table () {}
