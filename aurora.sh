# (see $urls)!/bin/bash
# Copyright (C) 2017 Nicolas Appriou

set -e


# url used to retrieve files are defined here
declare -A urls
urls[winetricks]=https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
urls[dcom98]=https://web.archive.org/web/20080222203526if_/http://download.microsoft.com/download/d/1/3/d13cd456-f0cf-4fb2-a17f-20afc79f8a51/DCOM98.EXE
urls[aurora]=http://aurora.iosphe.re/Aurora_latest.zip


# displays help text
function display_help {
  cat << HelpText
Usage: aurora.sh ACTION [OPTION]...

Available actions are:
  install         build a new installation of aurora
  start           start aurora
  winecfg         open winecfg for the aurora wine prefix
  help            display this

Options:
  -p, --path      path to Aurora wine prefix (default to ./wine)
  -v, --verbose   enable verbose mode (this will display wine debug info)
HelpText
}


# display an error message
function echo_error {
  echo -e "\033[0;31m$@\033[0m" >&2
}


# display a simple message
# those message are displayed in green in order to make them different from
# other program messages (such as wine or unzip)
function echo_message {
  echo -e "\033[0;32m$@\033[0m"
}


# check that a program given as argument is reachable on the system.
# if not, display an error message and exists the program with exit status 1
function ensure_program {
  local found="no"

  type $1 > /dev/null 2>&1 && found=yes

  if [ $found == no ]
  then
    echo_error "$1 is required but not installed. Aborting."
    exit 1
  fi
}


# download a file if it does not already exists
# first argument is the name url of the file to download (see $urls)
# second is the path where to store the file
function download_file {
  local file_url=${urls[$1]}
  local destination=$2/$(basename $file_url)

  if [ ! -e "$destination" ]
  then
    wget "$file_url" -O "$destination"
  fi
}


# install aurora
function perform_install {
  local dl_dir=$aurora_base_path/dl
  local reinstall

  trap 'echo_error "Something went wrong. Aurora is not installed."' ERR

  # if aurora is already installed, we may want to perform a reinstallation
  if [ -e "$WINEPREFIX" ];
  then
    read -r -p $'\033[0;33mAn existing installation of Aurora was found. Do you want to overwrite it ? [y/N] \033[0m' reinstall
    case $reinstall in
      [Yy])
        rm -rf "$WINEPREFIX"
        ;;
      *)
        exit 0
        ;;
    esac
  fi

  # downloaded files will end up in this directory
  [ -d "$dl_dir" ] || mkdir "$dl_dir"

  # get latest winetricks
  download_file winetricks "$dl_dir"
  chmod +x "$dl_dir/winetricks"
  local winetricks=$dl_dir/winetricks
  "$winetricks" --self-update

  # init wine and install tricks
  echo_message "Installing wine. You can tweak the settings in the winecfg windows if you want to"
  wine wineboot
  winecfg
  echo_message "Installing vb6run"
  "$winetricks" vb6run
  regsvr32 ole32.dll
  regsvr32 oleaut32.dll
  echo_message "Installing jet40"
  "$winetricks" jet40
  regsvr32 msjet40.dll
  echo_message "Installing mdac28"
  "$winetricks" mdac28

  # kill error14
  download_file dcom98 "$dl_dir"
  echo_message "We will now install dcom98.exe. Please enter C:\\windows\\system when prompted to extract files."
  wine "$dl_dir/dcom98.exe" /C

  # install aurora
  echo_message "Installing Aurora"
  download_file aurora "$dl_dir"
  unzip "$aurora_base_path/dl/Aurora_latest.zip" -d "$WINEPREFIX/drive_c/"
  # this is the dll that comes with the Simple Shutdown Timer trick
  cp "$WINEPREFIX/drive_c/Aurora/MSSTDFMT.DLL" "$WINEPREFIX/drive_c/windows/system32/"
  regsvr32 msstdfmt.dll

  # aurora won't start (or will crash ? Can't remember) if its log directory does not exist
  mkdir "$WINEPREFIX/drive_c/Logs"

  echo_message "Aurora has been installed. Enjoy your games !"
}


# copy database file in a secure place
function backup_database {
  local aurora_path=$WINEPREFIX/drive_c/Aurora
  local backup_path=$WINEPREFIX/aurora_backups
  local current_backup_path=$backup_path/$(date +%Y%m%d-%H%M%S)
  local max_backup_count=5

  # make sure the backup directory exists
  if [ ! -d $backup_path ]
  then
    mkdir $backup_path
  fi

  # backup files
  echo Making backup of Aurora database in $current_backup_path
  mkdir $current_backup_path
  cp $aurora_path/Stevefire.mdb $current_backup_path

  # remove backups in excess
  local obsolete_backups=$(ls $backup_path | grep -E '^[[:digit:]]{8}-[[:digit:]]{6}$' | sort -r | tail -n +$((max_backup_count + 1)))
  if [ ! -z "$obsolete_backups" ]
  then
    for old_backup in $obsolete_backups
    do
      echo Deleting old backup $backup_path/$old_backup
      rm -r $backup_path/$old_backup
    done
  fi
}


# starts Aurora with correct environment
function run_aurora {
  local aurora_path=$WINEPREFIX/drive_c/Aurora

  # make sure Aurora is installed
  if [ ! -d $aurora_path ]
  then
    echo_error "No aurora installation found in $aurora_path. Aborting."
    exit 1
  fi

  backup_database

  # Aurora needs to be started from its own directory
  cd $aurora_path
  LC_ALL="C" wine Aurora.exe
}


function run_winecfg {
  if [ ! -d $WINEPREFIX ]
  then
    echo_error "Aurora wine prefix is not found. Aborting."
    exit 1
  fi

  winecfg
}


# make sure we have all we need
ensure_program "wine"
ensure_program "wget"
ensure_program "unzip"

# build base path for the aurora install
aurora_base_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# set wine environment veriables
export WINEPREFIX=$aurora_base_path/wine
export WINEDLLOVERRIDES="ole32,oleaut32,rpcrt4=n,b"
export WINEARCH=win32


# get action to be taken by reading cli first argument
case $1 in
  install)
    taken_action="perform_install"
    ;;
  start)
    taken_action="run_aurora"
    ;;
  winecfg)
    taken_action="run_winecfg"
    ;;
  help)
    display_help
    exit 0
    ;;
  '')
    echo_error "You must tell me what to do..."
    display_help
    exit 1
    ;;
  *)
    echo_error Invalid action -- \'$1\'
    display_help
    exit 1
    ;;
esac


# parse other parameters
shift

while [ $# -gt 0 ]
do
  current_arg=$1
  shift

  case $current_arg in
    -p|--path)
      if [ ! -d $(dirname "$1") ]
      then
        echo_error "The $1 directory is not a valid wine prefix. Aborting."
        exit 1
      fi
      export WINEPREFIX=$(realpath "$1")
      shift
      ;;
    -v|--verbose)
      verbose_mode="on"
      ;;
    *)
      echo_error "unknown argument -- $current_arg"
      display_help
      exit 1
      ;;
  esac
done

if [ "$verbose_mode" != "on" ]
then
  export WINEDEBUG=-all
fi


$taken_action
