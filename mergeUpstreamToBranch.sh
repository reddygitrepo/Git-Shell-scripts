#!/bin/bash

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
createBranch()
{
	echo "debug $1"
	echo "debug ${2}"
	newBranch=""
	if [[ -z $1 ]]; then
		read -p "Branch name?:"
		echo $REPLY
		newBranch=$REPLY
	else
		newBranch=$2
	fi
	#prompt
	git checkout -B $newBranch
	git push -u origin HEAD
	echo ""
	echoIt "$newBranch branch created" $DEFAULT
	echoIt "Check the github.com network graph to ensure branch is at correct spot, and hit Y to proceed" $DEFAULT
	echoIt "https://github.com/$mUrl/$1/network" $ERROR
	prompt

}

clone(){
	echo "cloning $1"
	url="git@github.com:$mUrl/$1.git"
	git clone $url
	echo ""
}
logFilesChanges(){
    filename=$branchName_$DATE.log
    echo "----------------------" >> $DIR/$filename
    git config --get remote.origin.url >> $DIR/$filename
    echo "----------------------" >> $DIR/$filename
    git log -m -1 --name-status >> $DIR/$filename
}
doMerge(){
	git fetch upstream
	git merge --no-commit upstream/master
	git log
	git status
	echo
	echoIt "Merge completed, review log/status to ensure no conflicts."
	echoIt "***************************" $WARNING
	echoIt " IF CONFLICTS EXIST: resolve in another window/tool without committing and the hit Y at the prompt to continue with commit and push to your branch" $WARNING
	echoIt "***************************" $WARNING
	prompt
	git commit
	logFilesChanges
	#prompt
}
pushMerge(){
	git push origin HEAD
	git status
	echoIt "Check the github.com network graph to ensure branch is at correct spot" $DEFAULT
    echoIt "https://github.com/$mUrl/$1/network" $ERROR
	prompt
}
listRemotes(){
	git remote -v
	prompt
}
resetToMaster(){
	git checkout master
	git pull
	git branch
	echo ""
#	echo "Confirm master is checked out"
#	prompt
}
echoIt(){
    if [ $# -gt 1 ]
    then
        echo -e "\e[${2}m${1}\e[0m"
    else
        echo $1
    fi
}
usage()
{
    echo "Usage: $0 -c folder1 -u <TL | CT | SNI > [-b branch_name] repo-to-merge1 ..."
	echo "   folder1 = the folder to checkout master to"
	echo "   -u :"
	echo "       TL - TL is the source of the code to merge into SNI"
	echo "       CT - CT is the source of the code to merge into SNI"
	echo "       SNI - SNI is the source of code to merge into CT"
	echo ""
	echo "This script assumes 'git@github.com:SNI' is the base for the master repo and that the branch will initially be created from the master HEAD"
	echo ""
	echo "Example: "
	echo "   $0 -c /c/Workspaces/DWM -u git@github.com:TL -b June27_TLCodeDrop orion kepler_cxf"
	echo "   $0 -c /c/Workspaces/DWM -u git@github.com:TL orion kepler_cxf"
	echo "         This will end up prompting the user for the branch name to use"

        exit;
}
addUpstream(){
	git remote add upstream $uUrl/${1}.git
  	git remote -v
	echo ""
	echoIt "Confirm the upstream git url has been added." $DEFAULT
	prompt
}

#COLORS in output
PROMPT=3
DEFAULT=92
WARNING=91
DEBUG=2
ERROR=101

while getopts "c:b:u:h" o
do
        case "$o" in
                c)
                        repoHome=$OPTARG;;
                b)
                        branchName=$OPTARG;;
		u)
			upstream=$OPTARG;;
                h)      usage;;
                [?])    usage;;
        esac
done
shift $((OPTIND-1))

if [[ -z $repoHome || -z $upstream || $# = 0 ]]
then
	#echo "$repoHome;$upstream;$#"
	echo ""
	echoIt "***********Missing parameters!!!***********" $ERROR
	echo ""
	usage
fi


if [ "$upstream" == "TL" ]
then
	uUrl="git@github.com:TL"
	mUrl="SNI"
elif [ "$upstream" == "CT" ]
then
	uUrl="git@github.com:CTSNI"
	mUrl="SNI"
elif [ "$upstream" == "SNI" ]
then
	uUrl="git@github.com:SNI"
	mUrl="CTSNI"
else

	echo ""
	echoIt "***********Missing parameters!!!***********" $ERROR
	echo ""
	usage;
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=`date +%Y-%m-%d`

echo
echoIt "debug branch: $branchName" $DEBUG
echoIt "debug repo home: $repoHome" $DEBUG
echoIt "debug Upstream: $upstream" $DEBUG
echoIt "debug Upstream Url:$uUrl" $DEBUG
echoIt "debug masterUrl: git@github.com:$mUrl" $DEBUG
echo
prompt "continue"

cd $repoHome
mkdir merging
cd merging
for var in "$@"
do
    if [ "$var" == "platform-build-orion_base_web_app" ]
    then
        echo ""
        echoIt "!!!!! Do not use this script for 'platform-build-orion_base_web_app' repo" $ERROR
        echoIt "Please run the platformBuildMerge.sh script instead" $ERROR
        echo ""
        prompt "continue"
        continue;
    fi
	clone $var
	cd $var
	addUpstream $var
	resetToMaster
	createBranch $var $branchName
	doMerge
	pushMerge $var
	cd ..
	rm -fr $var
done
cd ..
rm -fr merging
