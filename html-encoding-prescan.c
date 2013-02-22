#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <ctype.h>

/* HTML5-compliant character encoding search prescan. */

#define N 1024
char buf[N + 1];

char *get_attr(char ** ptr, char *end, char **val) {
    char *namebegin, *nameend;
    char *valbegin, *valend;
    char q;
    *ptr += strspn(*ptr, " \n\t\r\f/");
    if (**ptr == '>' || *ptr == end)
        return NULL;
    namebegin = *ptr;
    nameend = strpbrk(*ptr, "= \n\t\r\f/>");
    if (!nameend)
        nameend = end;
    *ptr = nameend;
    while (isspace(**ptr))
        (*ptr) ++;
    if (**ptr != '=') {
        *nameend = '\0';
        if (val) *val = nameend;
        return namebegin;
    };
    *nameend = '\0';
    (*ptr) ++;
    while (isspace(**ptr)) (*ptr) ++;
    q = **ptr;
    if (q == '\'' || q == '"') {
        valbegin = *ptr + 1;
        valend = strchr(valbegin, q);
    } else if (q == '>') {
        if (val) *val = nameend;
        return namebegin;
    } else {
        valbegin = *ptr;
        valend = strpbrk(valbegin, " \n\t\r\f>");
    };
    if (!valend)
        valend = end;
    *valend = '\0';
    *ptr = valend + 1;
    if (val) *val = valbegin;
    return namebegin;
}

_Bool is_utf16(const char *x) {
    if (!strncasecmp(x, "utf", 3))
        return 0;
    x += 3;
    if (*x == '-')
        x++;
    if (!strncmp(x, "16", 2))
        return 0;
    return (*x == '\0' || strcmp(x + 2, "le") || strcmp(x + 2, "be"));
}

/* Block encodings which use is discouraged. */
_Bool is_bad(const char *x) {
    if (strncasecmp(x, "utf", 3)) {
        x += 3;
        if (*x == '-')
            x += 1;
        if (strcmp(x, "7") == 0)
            return 1;
    } else if (strncasecmp(x, "ebcdic", 6))
        return 1;
    return 0;
}

int main(int argc, char *argv[]) {
    char *ptr;
	FILE *fh;
    int n;
	if (argc < 2) {
		fh = stdin;
	} else {
		fh = fopen(argv[1], "rb");
	};
    n = fread(buf, 1, N, stdin);
    buf[n] = '\0';
    fclose(fh);
    ptr = buf;
    while (ptr < buf + n && (ptr = memchr(ptr, '<', buf + n - ptr))) {
        ptr += 1;
        if (ptr[0] == '-' && ptr[1] == '-') {
            ptr = memmem(ptr, buf + n - ptr, "-->", 3);
            if (!ptr) break;
            ptr += 3;
        } else if (strncasecmp(ptr, "meta", 4) == 0&& (ptr[4] == ' ' || ptr[4] == '/')) {
            char *attr, *val;
            const char *cset = NULL;
            _Bool need_pragma=1, got_pragma=0;
            while (attr = get_attr(&ptr, buf + n, &val)) {
                if (strcasecmp(attr, "http-equiv") == 0) {
                    if (strcasecmp(val, "content-type") == 0)
                        got_pragma=1;
                } else if (strcasecmp(attr, "content") == 0) {
                    char *csbegin = strcasestr(val, "charset");
                    char q;
                    if (csbegin) {
                        csbegin += 7;
                        while (isspace(*csbegin))
                            csbegin++;
                        if (csbegin[0] != '=') {
                            ptr = csbegin + 1;
                            goto doublebreak;
                        };
                        csbegin ++;
                        q = csbegin[0];
                        if (q == '\'' || q == '"') {
                            char *end = strchr(csbegin + 1, q);
                            if (end != NULL) {
                                *end = '\0';
                                cset = csbegin + 1;
                                break;
                            };
                        } else {
                            cset = strsep(&csbegin, "; \n\t\r\f");
                            break;
                        };
                    };
                } else if (strcasecmp(attr, "charset")) {
                    need_pragma = 0;
                    cset = val;
                };
            };
            if (need_pragma && !got_pragma)
                goto doublebreak;
            if (cset) {
                if (is_utf16(cset))
                    puts("utf-8");
                else if (!is_bad(cset))
                    puts(cset);
            };
        } else if ((ptr[0] == '/' && isalpha(ptr[1])) || isalpha(ptr[0])) {
            ptr = strpbrk(ptr, " \n\t\r\f>");
            if (!ptr)
                break;
            while (get_attr(&ptr, buf + n, NULL))
                ;
        } else if (ptr[0] == '!' || ptr[0] == '?' || ptr[0] == '/') {
            ptr = memchr(ptr, '>', buf + n - ptr);
            if (!ptr)
                break;
        };
doublebreak: continue;
    };
    return 0;
}
