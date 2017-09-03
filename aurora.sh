#!/bin/bash


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
  type $1 > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo_error "$1 is required butg not installed. Aborting."
    exit 1
  fi
}


# download a file if it does not already exists
# first argument is the url of the file to download, second is the
# path where to store the file
function download_file {
  local file_url=$1
  local destination=$2/$(basename $file_url)

  if [ ! -e $destination ]
  then
    wget $file_url -O $destination
  fi
}


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


# install aurora
function perform_install {
  local dl_dir=$aurora_base_path/dl
  local reinstall

  # if aurora is already installed, we may want to perform a reinstallation
  if [ -e $WINEPREFIX ];
  then
    read -r -p $'\033[0;33mAn existing installation of Aurora was found. Do you want to overwrite it ? [y/N] \033[0m' reinstall
    case $reinstall in
      [Yy])
        rm -rf $WINEPREFIX
        ;;
      *)
        exit 0
        ;;
    esac
  fi

  # downloaded files will end up in this directory
  [ -d $dl_dir ] || mkdir $dl_dir

  # get latest winetricks
  download_file https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks $dl_dir
  chmod +x $dl_dir/winetricks
  local winetricks=$dl_dir/winetricks

  # init wine and install tricks
  wine wineboot
  $winetricks vb6run
  regsvr32 ole32.dll
  regsvr32 oleaut32.dll
  $winetricks jet40
  regsvr32 msjet40.dll
  $winetricks mdac28

  # kill error14
  download_file https://mirrors.netix.net/sourceforge/v/vb/vb6extendedruntime/redist%20archive/dcom98.exe $dl_dir
  echo_message "We will now install dcom98.exe. Please enter C:\\windows\\system when prompted to extract files."
  wine $dl_dir/dcom98.exe /C

  # install aurora
  download_file http://aurora.iosphe.re/Aurora_latest.zip $dl_dir
  unzip $aurora_base_path/dl/Aurora_latest.zip -d $WINEPREFIX/drive_c/

  # replace dll (this is the Simple Shutdown Timer trick)
  cp $aurora_base_path/msstdfmt.dll $WINEPREFIX/drive_c/windows/system32/

  # aurora won't start (or will crash ? Can't remember) if its log directory does not exist
  mkdir $WINEPREFIX/drive_c/Logs
}


function run_aurora {
  local aurora_path=$WINEPREFIX/drive_c/Aurora

  # make sure Aurora is installed
  if [ ! -d $aurora_path ]
  then
    echo_error "No aurora installation found in $aurora_path. Aborting."
    exit 1
  fi

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
      if [ ! -d $(dirname $1) ]
      then
        echo_error "The $1 directory is not a valid wine prefix. Aborting."
        exit 1
      fi
      export WINEPREFIX=$(realpath $1)
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
