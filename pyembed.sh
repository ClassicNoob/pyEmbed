#!/bin/bash

#color codes
GREEN_B='\033[1;32m'
RED_B='\033[1;31m'
YELLOW_B='\033[1;33m'
GRAY_B='\033[1;37m'
UND='\033[4m'
RESET='\033[0m'
GREEN_PLUS="${GREEN_B}[+]${RESET}"
RED_MINUS="${RED_B}[-]${RESET}"
YELLOW_EX="${YELLOW_B}[!]${RESET}"

#Help page print
function printusage {
    echo
    echo -e "${GRAY_B}Usage:${RESET} pyembed.sh -s ${UND}source_file${RESET} -o ${UND}output_file${RESET} [-b ${UND}bed_file${RESET}]"
    echo
    echo "-h|--help)    Display this help page."
    echo "-s|--source)  Name of the file you want to hide."
    echo "-o|--output)  Output file you want to write to."
    echo "-b|--bed) Name of the file you want to embed into (optional, argparse.py by default)."
    echo
}

#process commnad line args
while [ "$1" != "" ]; do
    case $1 in
        
        -s|--source)
            shift
            sourceFile=$1
            ;;
        
        -o|--output)
            shift
            outFile=$1
            ;;
            
        -b|--bed)
            shift
            bedFile=$1
            ;;
        
        -h|--help)
            printusage
            exit 1
            ;;
    esac
    shift
done

#various if statements to verify the existence of necessary information
if [ -z "$sourceFile" ]; then
    echo -e "${RED_MINUS} No source file specified. Please specify what file you want to embed with -s."
    exit 1

elif [ ! -f $sourceFile ]; then
    echo -e "${RED_MINUS} Specified source file not found."
    exit 1

elif [ -z "$outFile" ]; then
    echo -e "${RED_MINUS} No output file specified. Please specify an output filename with -o."
    exit 1

elif [ -z "$bedFile" ]; then
    echo -e "${YELLOW_EX} No bed file explicitly specified. Using argparse by default . . ."
    bedFile=$(locate -b -r ^argparse.py$ | head -n 1)

elif [ -n "$bedFile" ] && [ ! -f $bedFile ]; then
    echo -e "${RED_MINUS} Specified bed file not found."
    exit 1
fi


#locates where the "middle" of the bed file is, and at what function we can insert right above.
bedFileLineCount=$(wc -l $bedFile | cut -d " " -f 1)
bedFileMidPoint=$((bedFileLineCount / 2))
appendDefLine=$(cat $bedFile | head -n $bedFileMidPoint | grep -n ^def | tail -n 1 | cut -d ":" -f 1)

#since we want the import statements to be grouped together, we must gather various info about import statements.
sourceImportBlock=$(cat $sourceFile | grep -e ^import -e "^from.*import.*")
sourceImportBlockLine=$(cat $sourceFile | grep -e ^import -e "^from.*import.*" | tail -n 1)
sourceImportBlockLineNum=$(cat $sourceFile | grep -n "${sourceImportBlockLine}" | head -n 1 | cut -d ":" -f 1)
bedImportLine=$(cat $bedFile | grep -n -e ^import -e "^from.*import.*" | tail -n 1 | cut -d ":" -f 1)

#if the source file has code outside of functions (which is likely), we want to make sure it runs and is at the bottom of the code.
firstMainLine=$(cat $sourceFile | grep -v -e ^[[:space:]] | grep -v -e ^class -e ^def -e ^import -e ^from.*import.* -e ^\# | sed '/^$/d' | head -n 1)
runBlockLine=$(cat $sourceFile | grep -n "$firstMainLine" | cut -d ":" -f 1)
runBlocks=$(cat $sourceFile | tail -n +${runBlockLine})

#builds each part into "blocks," then appends them all together in a proper order.
blockOne=$(cat $bedFile | head -n $bedImportLine)
blockTwo="$sourceImportBlock"
blockThree=$(cat $bedFile | head -n $(($appendDefLine -1)) | tail -n +$((${bedImportLine} +1)))
blockFour=$(cat $sourceFile | head -n $(($runBlockLine -1)) | tail -n +$((${sourceImportBlockLineNum} +1)))
blockFive=$(cat $bedFile | tail -n +${appendDefLine})
blockSix=$( echo "$runBlocks" | sed -e "s/^/\t/")

finalBuild=$(echo "$blockOne"; echo " "; echo "$blockTwo"; echo " "; echo "$blockThree"; \
             echo " "; echo "$blockFour"; echo " "; echo "$blockFive"; echo " "; \
             echo "if __name__ == '__main__':"; echo "$blockSix")

echo "$finalBuild" > $outFile

if [ -f $outFile ]; then
    echo -e "${GREEN_PLUS} File has been successfully built at ${outFile}."
else
    echo -e "${RED_MINUS} Unknown error has occurred."
    exit 1
fi
