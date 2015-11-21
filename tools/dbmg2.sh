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

function traceDebug {
	if $debug ; then
		traceCmd "[DEBUG] $@"
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
		  traceDebug "version : $OPTARG"
		  ;;
		g)
		  traceDebug "git was triggered! Parameter: $OPTARG"
		  ;;
		w)
		  traceDebug "-w was triggered!"
		  ;;
		x)
		  traceDebug "-x was triggered!"
		  ;;
		y)
		  traceDebug "-y was triggered!"
		  ;;
		z)
		  traceDebug "-z was triggered!"
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

function parseArgsOptionsVerbose {
	OPTIND=1
	while getopts ":vsd" opt; do
	  case $opt in
		v)
		  traceDebug "-v was triggered!"
		  verbose=true
		  ;;
		s)
		  traceDebug "-s was triggered!"
		  silent=true
		  ;;
		d)
		  debug=true
		  traceDebug "-d was triggered!"
		  ;;
	  esac
	done
}

function parseArgs {

	parseArgsOptionsVerbose "$@"
	parseArgsOptions "$@"
	shift $((OPTIND-1))
	
	if (($# == 0)); then
		usage
		exit 2
	fi

	# parse parameter
	conf_baseName=$1
	shift

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

function parseLstConfig {
	traceDebug "conf_baseName=$conf_baseName"
	if [[ ${conf_baseName:(-3)} == "lst" ]]; then
			conf_isLstMode=true
	fi
	
}

verbose=false
debug=false
silent=false

conf_isLstMode=false

#######################
# args parsing 
#######################

#######################
# Function handler
#######################

function handlerLstMode {
	if $conf_isLstMode; then
        traceCmd "> Multiple configurations mode"
        listFilename="$envConfigLocation/$conf_baseName"
		echo TODO gitInitWorkDir here or not ??
		RES=0
        if [ ! -f $listFilename ]; then
                traceCmd "> Bad Syntax"
                traceCmd "> List Filename $listFilename is not found"
                exit 1
        else
                for uniqueFile in `cat $listFilename`; do
                        traceCmd $uniqueFile
                        cd `pwd` ## TODO WY this ???
						CMD_OPTION=`echo "$*" | sed 's/'$conf_baseName'/'${uniqueFile}'/g'`
                        ./$CMD_NAME $CMD_OPTION
						RES=$?
						if [[ $RES != 0 ]];then
							exit $RES
						fi
                done
        fi
        # if $hasToCreateTagOK ;then
            # createGitTagOK $git_tag
        # fi
	fi
}

#######################
# Function handler
#######################


traceDebug "@=$@"
parseArgs "$@"
traceDebug "@=$@"

if [ "$conf_baseName" != "" ] ;then
	parseLstConfig "$conf_baseName"
	traceCmd "> conf_baseName=$conf_baseName"
fi

handlerLstMode "$@"

traceDebug "END $@"
exit 0
