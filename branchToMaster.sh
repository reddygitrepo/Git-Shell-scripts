#!/bin/bash

usage()
{
    echo "Usage: $0 -c folder1 -o <TL | CT | SNI > -b branch_name -r repo-to-merge"
	echo "   folder1 = the folder to checkout master to"
	echo "   -o :"
	echo "       TL - TL is the source of the master and branch"
	echo "       CT - CT is the source of the master and branch"
	echo "       SNI - SNI is the source of the master and branch"
	echo ""
	echo "This script assumes 'git@github.com:SNI' is the base for the master repo and that the branch will initially be created from the master HEAD"
	echo ""
	echo "Example: "
	echo "   $0 -c /c/Workspaces/DWM -o TL -b June27_TLCodeDrop -r orion "

        exit;
}
prompt()
{
    if [ "$1" == "continue" ]
    then
        echoIt "Press y/Y to continue" $PROMPT
        read -p "" -n 1 -r
    else
        echoIt "Are you sure? " $PROMPT
        read -p "" -n 1 -r
    fi
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
	    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
        fi
}
echoIt(){
    if [ $# -gt 1 ]
    then
        echo -e "\e[${2}m${1}\e[0m"
    else
        echo $1
    fi
}
clone(){
	echo "cloning $1"
	url="$mUrl/$1.git"
	git clone $url
	echo ""
}
doMerge(){
	#git fetch upstream
	git merge --no-commit $1
	git log
	git status
	echo
	echoIt "Merge completed, review log/status to ensure no conflicts."
	echoIt "***************************" $WARNING
	echoIt " IF CONFLICTS EXIST: resolve in another window/tool without committing and the hit Y at the prompt to continue with commit and push to your branch" $WARNING
	echoIt "***************************" $WARNING
	prompt
	git commit
#	logFilesChanges
	#prompt
}
pushMerge(){
	git push origin HEAD
	git status
	echoIt "Check the github.com network graph to ensure branch is at correct spot" $DEFAULT
    echoIt "https://github.com/$mUrl/$1/network" $ERROR
	prompt
}


#set -x

#repoHome="/c/Workspaces/TL/Internal"

#COLORS in output
PROMPT=3
DEFAULT=92
WARNING=91
DEBUG=2
ERROR=101

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=`date +%Y-%m-%d`

while getopts "c:r:b:o:h" o
do
        case "$o" in
        o)
            org=$OPTARG;;
        c)
            repoHome=$OPTARG;;
		r)
			repo=$OPTARG;;
		b)
			branch=$OPTARG;;
        h)      usage;;
	    [?])    usage;;
        esac
done

if [[ -z $repoHome || -z $org || -z $repo ]]
then
	#echo "$repoHome;$upstream;$#"
	echo ""
	echoIt "***********Missing parameters!!!***********" $ERROR
	echo ""
	usage
fi

if [ "$org" == "TL" ]
then
	mUrl="git@github.com:TL"
elif [ "$org" == "CT" ]
then
	mUrl="git@github.com:CTSNI"
elif [ "$org" == "SNI" ]
then
	mUrl="git@github.com:SNI"
elif [ "$org" == "test" ]
then
	mUrl="git@github.com:seidls"
else
	echo ""
	echoIt "***********Invalid or Missing parameters!!!***********" $ERROR
	echo ""
	usage;
fi
echoIt "repohome: $repoHome" $DEBUG
echoIt "repo: $repo" $DEBUG
echoIt "branch: $branch" $DEBUG
echoIt "organization: $org" $DEBUG
echoIt "debug Upstream Url:$uUrl" $DEBUG
echoIt "debug masterUrl: $mUrl" $DEBUG
echo
prompt "continue"

cd $repoHome
mkdir merging
cd merging
clone $repo
prompt
cd $repo

#git remote -v
git branch --track $branch origin/$branch
#git branch
prompt "Continue"

doMerge $branch
pushMerge $repo
echoIt "$branch pushed to master" $DEFAULT
rm -fr ../../merging
