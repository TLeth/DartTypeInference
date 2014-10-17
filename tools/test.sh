#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)
rm -f log

for f in $(ls tests/cases/)
do
    if [ ! -f tests/.stripped/$f ]; then
        strip.dart tests/cases/$f > tests/.stripped/$f
        dartfmt -w tests/.stripped/$f
    fi
    
    if [ tests/cases/$f -nt tests/.stripped/$f ]; then
        strip.dart tests/cases/$f > tests/.stripped/$f
        dartfmt -w tests/.stripped/$f
    fi
done

rm -f tests/output/*.dart
cp tests/.stripped/*.dart tests/output/

if [ $# -eq 0 ]; then

    dart ./bin/analyze.dart --dart-sdk ${dartDir%bin/dart} tests/output/tests.dart > /dev/null
    
    (for f in $(ls tests/cases/); do
        
        dartfmt -w tests/output/$f
        
        if [ $(diff <(cat tests/cases/$f) <(cat tests/output/$f) | wc -l) -eq 0 ]; then
            echo -e $f '\033[0;32mPass\033[0m'
            
        else 
            echo -e $f '\033[0;31mFail\033[0m'
            echo $f >> log
            echo "------------------------------" >> log
            echo "got" >> log
            cat tests/output/$f >> log
            printf "\n\n" >> log
            echo "expected" >> log
            cat tests/cases/$f >> log
            printf "\n\n" >> log
            echo "diff" >> log
            diff <(cat tests/cases/$f) <(cat tests/output/$f) >> log
            printf "\n\n" >> log
        fi
        
        done)|column -t
else
    (for arg in $*; do
        
        if [ -f tests/cases/$arg.dart ]; then
        
            dart ./bin/analyze.dart --dart-sdk ${dartDir%bin/dart} tests/output/$arg.dart > /dev/null
            dartfmt -w tests/output/$arg.dart
            
            if [ $(diff <(cat tests/cases/$arg.dart) <(cat tests/output/$arg.dart) | wc -l) -eq 0 ]; then
                echo -e $arg.dart '\033[0;32mPass\033[0m'
                
            else 
                echo -e $arg.dart '\033[0;31mFail\033[0m'
                echo $arg.dart >> log
                echo "------------------------------" >> log
                echo "got" >> log
                cat tests/output/$arg.dart >> log
                printf "\n\n" >> log
                echo "expected" >> log
                cat tests/cases/$arg.dart >> log
                printf "\n\n" >> log
                echo "diff" >> log
                diff <(cat tests/cases/$arg.dart) <(cat tests/output/$arg.dart) >> log
                printf "\n\n" >> log
            fi
        fi

    done)|column -t
    
fi

