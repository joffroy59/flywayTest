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
	traceCmd "  command"
	traceCmd "          Flyway command :"
	traceCmd "                  info (default)          Prints the details and status information about all the migrations"
	traceCmd "                  validate                Validates the applied migrations against the available ones."
	traceCmd "          			> with interactive validation"
	traceCmd "                  migrate                 Migrates the schema to the latest version. Flyway will create the metadata table automatically if it doesn't exist."
	traceCmd "                  clean                   FORBIDDEN Drops all objects in the configured schemas."
	traceCmd "                  baseline                Baselines an existing database, excluding all migrations upto and including baselineVersion."
	traceCmd "                  repair                  Repairs the metadata table"
	traceCmd "          @see flyway documentation more more details"
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
		  version=$OPTARG
		  ;;
		g)
		  traceDebug "git was triggered! Parameter: $OPTARG"
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
#version="latest"
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

function checkMigration {
	traceDebug "[checkMigration] dbScriptLocation/version=${dbScriptLocation}/${version}"
	if [ ! -d ${dbScriptLocation}/${version} ] ; then
	   traceCmd "> Error : Bad Syntax"
	   traceCmd "> Version $version has no dedicated dir ${dbScriptLocation}/${version}"
	   exit 1
	else
	   traceCmd "> Apply version $version context"
	fi
}

function checkDbConf {
	# Fichier de configuration de la base
	confFileName="$HOME/.db/repository/$conf_baseName.conf"
	traceDebug "[checkDbConf] $confFileName"
	if [ ! -f $confFileName ] ; then
			traceCmd "> Error : Bad Syntax"
			traceCmd "> File $confFileName is not found"
			exit 1
	fi

	traceDebug "[checkDbConf] source $confFileName"
	. $confFileName
}

function checkFlywayDBCommand {
	traceDebug "[checkFlywayDBCommand] $flyway_command"
	if [[ $flyway_command == "clean" ]] || [[ $flyway_command == "CLEAN" ]] ; then
		traceCmd "> FORBIDDEN COMMAND $flyway_command Drops all objects in the configured schemas."
		exit 1 
	fi

	traceDebug "[checkFlywayDBCommand] allowedCommands=${allowedCommands[*]}"
	if ! [[ " ${allowedCommands[*]} " == *" $flyway_command "* ]] ; then
			traceCmd "> Error : Bad Syntax"
			traceCmd "> <$flyway_command> command does not exist"
			traceCmd "allowedCommands=(${allowedCommands[*]})"
			traceCmd "> Type $CMD_NAME --help for more info"
			exit 1
	fi
}

function traceInfo {
	traceCmdVerbose ">   Driver :      $driver"
	traceCmdVerbose ">   URL :         $url"
	traceCmdVerbose ">   Schema :      $schemas"
	traceCmdVerbose ">   File Prefix : $prefix"
	traceCmdVerbose ">   User :        $user"
	traceCmdVerbose ">   Password :    (hidden)"

	traceCmd "> Running <$flyway_command> command on <$conf_baseName> schema"
}

function createFlywayFullCommand {
	flywayCommand="flyway -configFile=flyway.conf -user=$user -password=$password -driver=$driver -schemas=$schemas -url=$url "
	flywayCommand="$flywayCommand -locations=filesystem:${dbScriptLocation}/${version}"
	flywayCommand="$flywayCommand -sqlMigrationPrefix=$prefix"
	flywayCommand="$flywayCommand -outOfOrder=true"
	flywayCommand="$flywayCommand -placeholders.schema=$schemas"
	flywayCommand="$flywayCommand $command"

#	if [[ $version != "latest" ]] ; then
#		flywayCommand="$flywayCommand -target=$version"
#	fi

	if $verbose ; then
		flywayCommand="$flywayCommand -X"
	fi

	traceDebug "flywayCommand=$flywayCommand"
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
if ! $conf_isLstMode; then
	checkMigration
	checkDbConf
	checkFlywayDBCommand

	traceInfo
	createFlywayFullCommand
fi


traceDebug "END $@"
exit 0
