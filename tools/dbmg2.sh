#!/bin/bash
# Flyway caller
# Mai 2015
# Equipe stores.

# Version du script
mgdbVersion="0.4-alpha"

# Nom de la commande (alias)
CMD_NAME="$(basename $0)"

# Emplacement des fichiers des configuration
# (sans / à la fin)
#
# Il doit être composé de deux sous répertoires
#    - repository : fichiers .conf de configuration unitaire
#        - list:                fichiers .lst de listes de configurations unitaires
#
dbConfigLocation="$HOME/.db"
dbScriptLocation="../versions"
envConfigLocation="./env"

# Commandes flyway autorisées
allowedCommands=(migrate info validate baseline repair) #Clean is not allowed

CMD_PREFIX="[$CMD_NAME]"

GIT_MASTER_BRANCH=master
GIT_PREFIX="[GIT]"

function trace {
	if ! $silent ; then
		echo "$@"
	fi
}

function traceGit {
	trace "$GIT_PREFIX $@"
}

function traceCmd {
	trace "$CMD_PREFIX $@"
}

function traceCmdVerbose {
	if $verbose ; then
		traceCmd "$@"
	fi
}

function usage {
	traceCmd "DataBase Migration manaGer"
	traceCmd
	traceCmd "$CMD_NAME [-h] [-g [-r|--tagOK] <TAG>] <conf_baseName> [command] [options]"
	traceCmd "$CMD_NAME [options] <conf_baseName> [flyway_command]"
	traceCmd "  conf_baseName"
	traceCmd "          DB name stored in ~/.db/repository/<conf_baseName>.conf"
	traceCmd
	traceCmd "          Must define variables user,password,url,driver,schema"
	traceCmd "          Driver must be in default classpath"
	traceCmd "          If begins with list/prefix, it will look for a .lst file in ~/repository/list"
	traceCmd
	traceCmd "  options : "
	traceCmd "          -h            Show this help"
	traceCmd "          -g <TAG>      Set git repository to tag <TAG>"
	traceCmd "          -t <version>  Define target version"
	traceCmd "          -v            Verbose Mode"
	traceCmd "          -s            Silent Mode"
	traceCmd "          -d            Debug Mode"
	traceCmd
}

function parseArgsOptions {
	OPTIND=1
	while getopts ":wxyzvsdhg:t:" opt; do
	  case $opt in
		t)
		  echo "version : $OPTARG"
		  ;;
		g)
		  echo "git was triggered! Parameter: $OPTARG"
		  ;;
		v)
		  traceCmdVerbose "-v was triggered!"
		  verbose=true
		  ;;
		s)
		  traceCmdVerbose "-s was triggered!"
		  silent=true
		  ;;
		d)
		  traceCmdVerbose "-d was triggered!"
		  debug=true
		  ;;
		w)
		  traceCmdVerbose "-w was triggered!"
		  ;;
		x)
		  traceCmdVerbose "-x was triggered!"
		  ;;
		y)
		  traceCmdVerbose "-y was triggered!"
		  ;;
		z)
		  traceCmdVerbose "-z was triggered!"
		  ;;
		h)
		  usage
		  exit 1
		  ;;
		\?)
		  trace "Invalid option: -$OPTARG"
		  exit 1
		  ;;
		:)
		  trace "Option -$OPTARG requires an argument." >&2
		  exit 1
		  ;;		  
	  esac
	done
}

function parseArgs {

	parseArgsOptions "$@"
	shift $((OPTIND-1))
	
	if (($# == 0)); then
		usage
		exit 2
	fi

	# parse parameter
	conf_baseName=$1
	shift
	traceCmd "> conf_baseName=$conf_baseName"

	parseArgsOptions "$@"
	shift $((OPTIND-1))

	# Flyway db command management
	flyway_command="info"
	if [[ $# != 0 ]] ; then
		flyway_command=$1
		shift
	fi
	traceCmd "> Applying <$flyway_command> flyway command"
	
}

#######################
# GIT function
#######################
GIT_ORIGINAL_BRANCH=
GIT_OPTIONS=
BF_OPTIONS=

function gitMoveToBranch {
	git_tag=$1
	
	traceGit "Git Operation enable"
	if [[ "$git_tag" == "" ]]; then
		traceGit "No tag specified"
		usage
		exit 1;
	fi
	
	## update all tag from remote
	git fetch --tags
	
	if [[ ! $(git rev-list $git_tag 2>/dev/null) ]]; then
		traceGit "The tag $git_tag does not exists in git repository"
		exit 1;
	fi
	
	gitCheckout $git_tag
	if [[ $? -eq 0 ]]; then 
		traceGit "set git workspace to tag : $git_tag  [OK]"
	else
		traceGit "set git workspace to tag : $git_tag  [KO]"
		exit 2
	fi
}

function gitShowCurrentBranch {
	traceGit "current branch : $(git rev-parse --abbrev-ref HEAD)"
}

function gitBackupWorkingCopy {
	git stash
	traceGit "Your working directory Changes was Stash"
}

function gitCheckStatus {
	if ! git diff-index --quiet HEAD --; then
		traceGit "Your working directory is not clean"
		gitBackupWorkingCopy
	fi
}

function gitCheckout {
	GIT_CHECKOUT_OPTRIONS=""
	if ! $verbose ; then
		GIT_CHECKOUT_OPTRIONS="--quiet"
	fi
	git checkout $GIT_CHECKOUT_OPTRIONS $1
}

function executeGitPreTreatment {
	GIT_BRANCH=$1
	gitCheckStatus
	gitMoveToBranch $GIT_BRANCH
	gitShowCurrentBranch
}

function executeGitPostTreatment {
	GIT_BRANCH=$1
	traceGit "Git Operation restore enable [restore original branch : $GIT_BRANCH]"
	gitCheckout $GIT_BRANCH
	if [[ $? -eq 0 ]]; then 
		traceGit "set git workspace to branch : $GIT_BRANCH  [OK]"
	else
		traceGit "set git workspace to branch : $GIT_BRANCH  [KO]"
		exit 2
	fi
	gitShowCurrentBranch
}

function createGitTagOK {
	TAG_ORIGINAL=$1
	traceGit "Command to push TAG OK:"
	traceGit "git tag ${TAG_ORIGINAL}_PP_OK ; git push --tags"
}

function gitInitWorkDir {
	if $hasToExecuteGitPreTreatment ; then
		executeGitPreTreatment $git_tag
	fi
}

function gitCreateGitTagOK {
	if $hasToCreateTagOK ;then
		createGitTagOK $git_tag
	fi
}

function gitExecuteGitPostTreatment {
	if $hasToExecuteGitPostTreatment ; then
		executeGitPostTreatment $GIT_ORIGINAL_BRANCH
	fi
}

#######################
# GIT function
#######################

verbose=false
debug=false
silent=false
#######################
# args parsing 
#######################

parseArgs "$@"

exit 5
