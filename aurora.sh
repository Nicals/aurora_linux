#!/bin/bash


# check that a program given as argument is reachable on the system.
# if not, display an error message and exists the program with exit status 1
function ensure_program {
  type $1 > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo >&2 "$1 is required but not installed. Aborting."
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
Usage: aurora.sh ACTION

Available actions are:
  install         build a new installation of aurora
  start           start aurora
  winecfg         open winecfg for the aurora wine prefix
  help            display this
HelpText
}


# install aurora
function perform_install {
  local dl_dir=$aurora_base_path/dl
  local reinstall

  # if aurora is already installed, we may want to perform a reinstallation
  if [ -e $aurora_base_path/wine ];
  then
    read -r -p $'\033[0;31mAn existing installation of Aurora was found. Do you want to overwrite it ? [y/N] \033[0m' reinstall
    case $reinstall in
      [Yy])
        rm -rf $aurora_base_path/wine
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
  echo -e "\033[0;32mWe will now install dcom98.exe. Please enter C:\\windows\\system when prompted to extract files\033[0m"
  wine $dl_dir/dcom98.exe /C

  # install aurora
  download_file http://aurora.iosphe.re/Aurora_latest.zip $dl_dir
  unzip $aurora_base_path/dl/Aurora_latest.zip -d $aurora_base_path/wine/drive_c/

  # replace dll (this is the Simple Shutdown Timer trick)
  cp $aurora_base_path/msstdfmt.dll $aurora_base_path/wine/drive_c/windows/system32/

  # aurora won't start (or will crash ? Can't remember) if its log directory does not exist
  mkdir $aurora_base_path/wine/drive_c/Logs
}


function run_aurora {
  # Aurora needs to be started from its directory
  cd $aurora_base_path/wine/drive_c/Aurora
  LC_ALL="C" wine aurora.exe
}


function run_winecfg {
  if [ ! -d $aurora_base_path/wine ]
  then
    echo -e "\033[0;31mAurora wine prefix is not found. Aborting\033[0m"
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


case $1 in
  install)
    perform_install
    ;;
  start)
    run_aurora
    ;;
  winecfg)
    run_winecfg
    ;;
  help)
    display_help
    ;;
  '')
    echo You must tell me what to do...
    display_help
    exit 1
    ;;
  *)
    echo Invalid action -- \'$1\'
    display_help
    exit 1
    ;;
esac
