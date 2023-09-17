BEGIN { FS="\n\n-----\n\n"; RS="\0" }

{
    for(i=1; i<=NF; i++) {
        fn="/tmp/b/output_"i
        print $i >> fn
    }
}