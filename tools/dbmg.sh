#!/bin/bash
# Flyway caller
# Mai 2015
# Equipe stores.

# Version du script
mgdbVersion="0.4-alpha"

# Nom de la commande (alias)
CMD_NAME="$(basename $0)"

# Emplacement des fichiers des configuration
# (sans / � la fin)
#
# Il doit �tre compos� de deux sous r�pertoires
#    - repository : fichiers .conf de configuration unitaire
#        - list:                fichiers .lst de listes de configurations unitaires
#
dbConfigLocation="$HOME/.db"
dbScriptLocation="../versions"
envConfigLocation="./env"

# Commandes flyway autoris�es
allowedCommands=(migrate info validate baseline repair) #Clean is not allowed

CMD_PREFIX="[$CMD_NAME]"

GIT_MASTER_BRANCH=master
GIT_PREFIX="[GIT]"

function traceGit {
	echo "$GIT_PREFIX $1"
}

function traceCmd {
	echo "$CMD_PREFIX $1"
}

function traceCmdVerbose {
	if $verbose ; then
		traceCmd "$1"
	fi
}

function usage {
	traceCmd "DataBase Migration manaGer"
	traceCmd
	traceCmd "## USAGE ##"
	traceCmd "$CMD_NAME [-git [-r|--tagOK] <TAG>] [-basefolder <basefolder>] <basename> [command] [options]"
	traceCmd
	traceCmd "  -git [-r] <TAG>"
	traceCmd "          if set, execute git command before start of flyway DB using git specified tag <TAG> (git fetch+checkout)"
	traceCmd "          -r : restore to 'master' branch after work"
	traceCmd

	traceCmd "  basename"
	traceCmd "          DB name stored in ~/.db/repository/<basename>.conf"
	traceCmd
	traceCmd "          Must define variables user,password,url,driver,schema"
	traceCmd "          Driver must be in default classpath"

	traceCmd "          If begins with list/prefix, it will look for a .lst file in ~/repository/list"
	traceCmd
	traceCmd "  command"
	traceCmd "          Flyway command among"
	traceCmd "                  info (default)          Prints the details and status information about all the migrations"
	traceCmd "                  validate                Validates the applied migrations against the available ones."
	traceCmd "          > with interactive validation"
	traceCmd "                  migrate                 Migrates the schema to the latest version. Flyway will create the metadata table automatically if it doesn't exist."
	traceCmd "                  clean                   FORBIDDEN Drops all objects in the configured schemas."
	traceCmd "                  baseline                Baselines an existing database, excluding all migrations upto and including baselineVersion."
	traceCmd "                  repair                  Repairs the metadata table"
	traceCmd "          @see flyway documentation more more details"

	traceCmd
	traceCmd "  ## Options ## "
	traceCmd "          --help          Show this help"
	traceCmd "          --version       Show script version"
	traceCmd
	traceCmd "      --target <version>   Define target version"
	traceCmd
	traceCmd "  --verbose"
	traceCmd "  -v              Active Debug Mode"
	traceCmd
	traceCmd "  Based on FlyWay DB"
	traceCmd "  @see http://flywaydb.org/"
	traceCmd
	traceCmd "  @since 2015"
	traceCmd "  @copyright Decathlon"
	traceCmd "  @author Damien Cuvillier <external.z01dcuvi@btwin.com> <damien@gotan.io>"
	traceCmd "  @author Jerome OFFROY <external.z01dcuvi@btwin.com> <damien@gotan.io>"
    traceCmd
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

#######################
# args parsing 
#######################
if [[ $# == 1 ]] && [[ $1 == "--version" ]] ; then
        traceCmd "DataBase Migration manaGer"
        traceCmd $mgdbVersion
        exit 0
fi

if [[ $# == 1 ]] && [[ $1 == "--help" ]]; then
		usage
        exit 0;
fi


if [[ $# < 1 ]]; then
        traceCmd "> No <basename> defined"
		usage
        traceCmd
        exit 0
fi

#if [ ! -d ./$version ] ; then
#       traceCmd "> Error : Bad Syntax"
#       traceCmd "> Version $version has no dedicated dir"
#       exit 1
#else
#       traceCmd "> Apply version $version context"
#fi

hasToExecuteGitPreTreatment=false
hasToExecuteGitPostTreatment=false
hasToCreateTagOK=false

haveBasefodlerSet=false
dbScriptLocationRoot="${dbScriptLocation}/${version}"

## test git option in order to execute/not git command before start of flywaydb
if [[ $1 == "-git" ]]; then
	GIT_OPTIONS=$1
	shift
	if [[ $# -gt 1 ]] && [[ $1 == "-r" ]] ; then
			hasToExecuteGitPostTreatment=true
			GIT_ORIGINAL_BRANCH=$GIT_MASTER_BRANCH
			GIT_OPTIONS="$GIT_OPTIONS $1"
			shift
	fi	
	if [[ $# -gt 1 ]] && [[ $1 == "--tagOK" ]] ; then
			hasToCreateTagOK=true
			shift
	fi	
	git_tag=$1
	GIT_OPTIONS="$GIT_OPTIONS $1"
	shift
	hasToExecuteGitPreTreatment=true
fi

## test git option in order to execute/not git command before start of flywaydb
if [[ $1 == "-basefolder" ]]; then
	BF_OPTIONS=$1
	shift	
	BF_FOLDER=$1
	BF_OPTIONS="$BF_OPTIONS $1"
	shift
	haveBasefodlerSet=true
fi

baseName=$1
shift
if [[ ${baseName:(-3)} == "lst" ]]; then
        traceCmd "> Multiple configurations mode"
        listFilename="$envConfigLocation/$baseName"
		gitInitWorkDir
        if [ ! -f $listFilename ]; then
                traceCmd "> Bad Syntax"
                traceCmd "> List Filename $listFilename is not found"
                exit 1
        else
                for uniqueFile in `cat $listFilename`; do
                        traceCmd $uniqueFile
                        cd `pwd`
                        $CMD_NAME $GIT_OPTIONS $BF_OPTIONS $uniqueFile $*
                done
        fi
        if $hasToCreateTagOK ;then
            createGitTagOK $git_tag
        fi
        exit 0
fi

stcom_version=$1
shift
if $haveBasefodlerSet ;then
	dbScriptLocationRoot=$BF_FOLDER
fi

if [ ! -d ${dbScriptLocationRoot} ] ; then
   traceCmd "> Error : Bad Syntax"
   traceCmd "> Version $version has no dedicated dir ${dbScriptLocationRoot}"
   exit 1
else
   traceCmd "> Apply version $version context"
fi


# Fichier de configuration de la base
confFileName="$HOME/.db/repository/$baseName.conf"
if [ ! -f $confFileName ] ; then
        traceCmd "> Error : Bad Syntax"
        traceCmd "> File $confFileName is not found"
        exit 1
fi

. $confFileName

# Gestion des commandes
if [[ $# == 0 ]] ; then
        traceCmd "> Applying <info> default flyway command"
        command="info"
else
        command=$1
fi
shift


if [[ $command == "clean" ]] || [[ $command == "CLEAN" ]] ; then
    traceCmd "> FORBIDDEN COMMAND Drops all objects in the configured schemas."
    exit 1 
fi


if ! [[ " ${allowedCommands[*]} " == *" $command "* ]] ; then
        traceCmd "> Error : Bad Syntax"
        traceCmd "> <$command> command does not exist"
        traceCmd "> Type $CMD_NAME --help for more info"
        exit 1
fi

verbose=false
version="latest"
while [[ $# > 0 ]] ; do
        if [[ $1 == "--verbose" ]] || [[ $1 == "-v" ]] ; then
                verbose=true
                traceCmd "> Verbose Mode active"
        fi
    if [[ $1 == "--target" ]] ; then
        shift
        version=$1
        traceCmd "> Max version $version"
    fi
        shift
done
#######################
# args parsing 
#######################

traceCmdVerbose ">   Driver :      $driver"
traceCmdVerbose ">   URL :         $url"
traceCmdVerbose ">   Schema :      $schemas"
traceCmdVerbose ">   File Prefix : $prefix"
traceCmdVerbose ">   User :        $user"
traceCmdVerbose ">   Password :    (hidden)"

traceCmd "> Running <$command> command on <$baseName> schema"


#######################
# preprare flyway cmd
#######################
flywayCommand="flyway -configFile=flyway.conf -user=$user -password=$password -driver=$driver -schemas=$schemas -url=$url "
flywayCommand="$flywayCommand -locations=filesystem:${dbScriptLocationRoot}"
flywayCommand="$flywayCommand -sqlMigrationPrefix=$prefix"
flywayCommand="$flywayCommand -outOfOrder=true"
flywayCommand="$flywayCommand -placeholders.schema=$schemas"
flywayCommand="$flywayCommand $command"

if [[ $version != "latest" ]] ; then
    flywayCommand="$flywayCommand -target=$version"
fi

if $verbose ; then
	flywayCommand="$flywayCommand -X"
	traceCmd "> Running : $flywayCommand"
fi
#######################
# preprare flyway cmd
#######################

#######################
# execution 
#######################

gitInitWorkDir

traceCmdVerbose "$flywayCommand"
$flywayCommand

gitCreateGitTagOK 
gitExecuteGitPostTreatment

#######################
# execution 
#######################