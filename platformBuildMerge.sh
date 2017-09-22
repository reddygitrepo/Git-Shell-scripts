#!/bin/bash

usage()
{
    echo "Usage: $0 -c folder1 -u 		 TL | CT | SNI > [-b branch_name]"
	echo "   folder1 = the folder to checkout master to"
	echo "   -u :"
	echo "       TL - TL is the source of the code to merge into SNI"
	echo "       CT - CT is the source of the code to merge into SNI"
	echo "       SNI - SNI is the source of code to merge into CT"
	echo ""
	echo "Example: "
	echo "   $0 -c /c/Workspaces/DWM -u git@github.com:TLrnal -b June27_TLCodeDrop"
	echo "   $0 -c /c/Workspaces/DWM -u git@github.com:TLrnal"
	echo "         This will end up prompting the user for the branch name to use"
    exit;
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
	echoIt "Merge completed, review log/status to ensure no conflicts."
	echoIt "***************************" $WARNING
	echoIt " IF CONFLICTS EXIST: resolve in another window/tool without committing and the hit Y at the prompt to continue with commit and push to your branch" $WARNING
	echoIt "***************************" $WARNING
	prompt
	git commit
	logFilesChanges
}
resetToMaster(){
	git checkout master
	git pull
	git branch
	echo "checked out master"
}
listRemotes(){
	git remote -v
	prompt
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
pushMerge(){
	git push origin HEAD
	git status
	echoIt "Check the github.com network graph to ensure branch is at correct spot" $DEFAULT
    echoIt "https://github.com/$mUrl/$1/network" $ERROR
	prompt
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
		newBranch=$1
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
addUpstream(){
#	uUrl="git@github.com:TLrnal"
        git remote add upstream $uUrl/${1}.git
        git remote -v
        echo ""
        echoIt "Confirm the upstream git url has been added." $DEFAULT
        prompt
}
clone(){
	echo "cloning $1"
	url="git@github.com:$mUrl/$1.git"
	git clone $url
	echo ""
}
#COLORS in output
PROMPT=3
DEFAULT=92
WARNING=91
DEBUG=2
ERROR=101

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATE=`date +%Y-%m-%d`

#set -x
repo="platform-build-orion_base_web_app"
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

if [[ -z $repoHome || -z $upstream ]]
then
	#echo "$repoHome;$upstream"
	echo ""
	echoIt "***********Missing parameters!!!***********" $ERROR
	echo ""
	usage
fi


if [ "$upstream" == "TL" ]
then
	uUrl="git@github.com:TLrnal"
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

echoIt "debug branch: $branchName" $DEBUG
echoIt "debug repo home: $repoHome" $DEBUG
echoIt "debug Upstream: $upstream" $DEBUG
echoIt "debug Upstream Url:$uUrl" $DEBUG
echoIt "debug masterUrl: git@github.com:$mUrl" $DEBUG

cd $repoHome
clone $repo
cd $repo


resetToMaster
prompt
addUpstream $repo
createBranch $branchName
prompt
doMerge
echo
echo

echoIt "Handling Conflict by sing upstream Berksfile.lock as source before replacing url/commit #" $DEFAULT
echo
git checkout --theirs Berksfile.lock
echoIt "replacing git URLs" $DEBUG
echo
if [ "$upstream" == "TL" ]
then
	commitSrc="https://github.com/SNI"
	sed -i -e 's/bitbucket.org:TLlineinteractive/github.com:SNI/g' Berksfile.lock
elif [ "$upstream" == "SNI" ]
then
	commitSrc="https://github.com/CTSNI"
	sed -i -e 's/github.com:SNI/github.com:CTSNI/g' Berksfile.lock
else
	echoIt "error" $ERROR
	exit
fi

echoIt "replacing revisions" $DEBUG
repos=( kepler_app.git orion_base.git orion_infrastructure.git orion_jenkins.git orion_platform-cookbook.git)
#set -x
for x in ${repos[@]}; do
    current=`awk -v lines=1  '/'"$x"'/ {for(i=lines;i;--i)getline; print $0 }' Berksfile.lock |cut -d : -f2 |tr -d '[:space:]'`
    echoIt "Enter commit number for $x from $commitSrc:" $PROMPT
    read -p ""
    newCommit=$REPLY
    sed -i -e 's/'"${current}"'/'"${newCommit}"'/g' Berksfile.lock
done

git diff Berksfile.lock
prompt
git commit -am "Modifed BerksFile.log with sni values & commit numbers by $0"
pushMerge
cd $repoHome
rm -fr $repo



