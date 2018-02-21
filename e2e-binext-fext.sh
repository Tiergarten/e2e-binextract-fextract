set -e

if [[ "${DEBUG}" == "1" ]]; then
	set -x
fi

EXTRACTOR_NAME="ext-dump-ins"

EXTRACTORS=( ext-dump-ins ext-mem-rw-dump )

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PINTOOL_INSTALL_PATH="${INSTALL_DIR}/../../dependencies/pin-3.5-97503-gac534ca30-msvc-windows"
# FIXME: This is hardcoded 64bit dll...
PINTOOLS_PATH="${INSTALL_DIR}/obj-intel64"

function get_pin_tool_path() {
	local extractorName=$1

	echo "${PINTOOLS_PATH}/a${extractorName}.dll"
}

function clean() {
	
	if [[ "$1" == "all" ]]; then
		rm *.out
	fi

	make clean
	
	rm *.pdb *.ilk *.exe *.obj
}

function dotest() {
	python -m unittest discover --pattern=*.py	
}

function build() {
	cl traceme.c /DEBUG /Zi

	if [[ $(is64) -eq 1 ]]; then
		make all TARGET=intel64
	else
		make all TARGET=ia32
	fi
}

function pin_proc() {
	local targetExe=$1
	local pin=$2

	$(get_pin_exe_path) -t ${pin} -- ${targetExe}
}

function pin_pid() {
	local pid=$1
	local pin=$2

	$(get_pin_exe_path) -pid ${pid} -t ${pin}
}

function get_pin_exe_path() {
	if [[ $(is64) -eq 0 ]]; then
		echo "${PINTOOL_INSTALL_PATH}/pin.exe"
	else
		echo "${PINTOOL_INSTALL_PATH}/intel64/bin/pin.exe"
	fi
}

function is64() {
	# Visual studio vcvars.bat sets this...
	if [[ "${VSCMD_ARG_TGT_ARCH}" == "x64" ]]; then
		echo 1
	else
		echo 0
	fi
}

function get_feature_extractor_output_file() {
	local extractorName=$1
	echo "f${extractorName}.out"
}

function main() {
	clean all 2>/dev/null | true
	dotest
	build

	for extractor in "${EXTRACTORS[@]}"; do
	
		local pintool_dll_path=$(get_pin_tool_path ${extractor})
		pin_proc "./traceme.exe" $(cygpath -w "${pintool_dll_path}")

		local feature_output_file=$(get_feature_extractor_output_file ${extractor})
		time python "f${extractor}.py" > ${feature_output_file}
		head f${extractor}.out
		wc -l *.out
	done
		
	clean 2>/dev/null | true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi