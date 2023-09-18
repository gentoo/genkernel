function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }

BEGIN { FS="\n\n-----\n\n"; RS="\0" }

{
    for(i=1; i<=NF; ++i) {
        S = trim($i)
        split(S, A, "\n")
        L = length(A)
        S_begin = A[1]
        S_end = A[L]
        if (substr(S_begin, 0, 7) != "%begin " || substr(S_end, 0, 5) != "%end ") {
            print "invalid section header/footer in: "FILENAME
            exit 1
        }
        section_name = substr(S_begin, 8)
        if (substr(S_end, 6) != section_name) {
            print "invalid section name in: "FILENAME
            exit 1
        }
        filename="out/temp/"section_name
        for(j=2; j<L; ++j)
            print A[j] >> filename
    }
}
