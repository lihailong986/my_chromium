#!/bin/bash
# Copyright (c) 2021 Huawei Device Co., Ltd.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# use ./build.sh -nosym to build content_shell without symbol.
set -e
basedir=`dirname "$0"`
CUR_DIR=$PWD
ROOT_DIR="${CUR_DIR%/src*}""/src"
# Global variables.
BUILD_TARGET_WEBVIEW="ohos_nweb_hap"
BUILD_TARGET_BROWSERSHELL="ohos_browser_shell"
BUILD_TARGET_NATIVE="libweb_engine web_render libnweb_render"
BUILD_TARGET_BROWSER_SERVICE="ohos_nweb_ex/browser_service"
BUILD_TARGET_BROWSER_SERVICE_HAR="browser_service_har"
TEXT_BOLD="\033[1m"
TEXT_NORMAL="\033[0m"

#Add build args begin
buildargs="
  target_os=\"ohos\"
  is_debug=false
  use_allocator=\"none\"
  is_official_build=true
  is_component_build=false
  is_chrome_branded=false
  use_official_google_api_keys=false
  use_ozone=true
  use_aura=true
  ozone_auto_platforms=false
  ozone_platform=\"headless\"
  ozone_platform_headless=true
  enable_extensions=true
  ffmpeg_branding=\"Chrome\"
  use_kerberos=false
  use_bundled_fontconfig=true
  enable_resource_allowlist_generation=false
  clang_use_chrome_plugins=false
  enable_message_center=true
  safe_browsing_mode=0
  use_custom_libcxx=false
  use_sysroot=false
  gpu_switch=\"on\"
  proprietary_codecs=true
  media_use_ffmpeg=true"
#Add build args end

buildgn=1
buildcount=0
buildccache=0
buildsymbol=0
buildproduct=""
buildarg_cpu="target_cpu=\"arm\""
buildarg_musl="use_musl=true"
build_dir="out/rk3568/"
build_product_name="product_name=\"rk3568\""
build_target="${BUILD_TARGET_NATIVE}"
build_output=""
artifact_mode=0
without_nweb_ex=0
build_sysroot="use_ohos_sdk_sysroot=false"

usage() {
  echo -ne "USAGE: $0 [OPTIONS] [PRODUCT]

${TEXT_BOLD}OPTIONS${TEXT_NORMAL}:
  -j N              force number of build jobs
  -ccache           Enable CCache.
  -t <target>       Build target, supports:
                      n Build native files.
                      b Build BrowserShell.
                      w Build NWeb WebView.
                      m Build NWebEx napi module.
                      M Build NWebEx napi npm package.
  -o <output_dir>   Output directory, for example: Default.
  -A, -artifact     Artifact mode, using pre-built NDK rather than building
                    them locally.

${TEXT_BOLD}PRODUCT${TEXT_NORMAL}:
  rk3568 rk3568_64
  Default is: rk3568
"
}

while [ "$1" != "" ]; do
  case $1 in
    "rk3568")
      buildarg_cpu="target_cpu=\"arm\""
      buildarg_musl="use_musl=true"
      build_dir="out/rk3568/"
      build_product_name="product_name=\"rk3568\""
    ;;
    "rk3568_64")
      buildarg_cpu="target_cpu=\"arm64\""
      buildarg_musl="use_musl=true"
      build_dir="out/rk3568_64/"
      build_product_name="product_name=\"rk3568\""
    ;;
    "-j")
      shift
      buildcount=$1
    ;;
    "-ccache")
      buildccache=1
    ;;
    "-sym")
      buildsymbol=1
    ;;
    "-t")
      shift
      build_target=$1
      ;;
    "-o")
      shift
      build_output=$1
      ;;
    "-artifact"|"-A")
      artifact_mode=1
      ;;
    "-without-nweb-ex")
      without_nweb_ex=1
      ;;
    "-h")
      usage
      exit 0
      ;;
    *)
      echo " -> $1 <- is not a valid option, please follow the usage below: "
      usage
      exit 1
    ;;
  esac
  shift
done

if [ "-${build_output}" != "-" ]; then
  build_dir="out/${build_output}/"
fi

case "${build_target}" in
  "w"|"${BUILD_TARGET_WEBVIEW}")
    build_target="${BUILD_TARGET_WEBVIEW}"
    ;;
  "b"|"${BUILD_TARGET_BROWSERSHELL}")
    build_target="${BUILD_TARGET_BROWSERSHELL}"
    [[ "-$buildarg_musl" == "-use_musl=true" ]] && build_sysroot="use_ohos_sdk_sysroot=true"
    ;;
  "n"|"${BUILD_TARGET_NATIVE}")
    build_target="${BUILD_TARGET_NATIVE}"
    ;;
  "m"|"${BUILD_TARGET_BROWSER_SERVICE}")
    build_target="${BUILD_TARGET_BROWSER_SERVICE}"
    build_sysroot="use_ohos_sdk_sysroot=true"
    [[ "-${build_product_name}" != "-product_name=\"rk3568\"" ]] && echo \
      "Use -t M instead of -t m to build ${build_target} for current platform."\
      && exit 1
    ;;
  "M"|"${BUILD_TARGET_BROWSER_SERVICE_HAR}")
    build_target="${BUILD_TARGET_BROWSER_SERVICE_HAR}"
    [[ "-$buildarg_musl" == "-use_musl=true" ]] && build_sysroot="use_ohos_sdk_sysroot=true"
    ;;
  *)
    echo "Invalid build_target: ${build_target}"
    exit 2
    ;;
esac

SYMBOL_LEVEL=1
if [ $buildsymbol = 1 ]; then
  SYMBOL_LEVEL=2
fi

if [ $buildcount = 0 ]; then
  #buildcount=`grep processor /proc/cpuinfo | wc -l`
  buildcount=40
fi

if [ $buildccache = 1 ]; then
  if [ $buildcount = 0 ]; then
    buildcount=64
  fi
  GN_ARGS="cc_wrapper=\"ccache\" clang_use_chrome_plugins=false linux_use_bundled_binutils=false"
  export CCACHE_CPP2=yes
fi

if [ ${artifact_mode} -eq 1 ]; then
  GN_ARGS="${GN_ARGS} build_chromium_with_ohos_src=false"
else
  GN_ARGS="${GN_ARGS} build_chromium_with_ohos_src=true"
fi

# Extract ohos-sdk.
if [ -f "src/ohos_sdk/.install" ]; then
  bash "src/ohos_sdk/.install"
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install ohos-sdk, abort!"
    exit 1
  fi
fi

if [ -f "${ROOT_DIR}/ohos_nweb_hap/BUILD.gn" ]; then
  buildargs="${buildargs}
  enable_ohos_nweb_hap=true"
fi

if [ ${without_nweb_ex} -ne 1 -a ${artifact_mode} -eq 1 ]; then
  if ! [ -d "${ROOT_DIR}"/"${build_dir}" ]; then
    mkdir -p "${ROOT_DIR}"/"${build_dir}"
  fi

  BUILD_CONFIG_NAME="ohos_nweb_ex_config.gn"
  CONFIG_AUTO_GEN_DIR="build/config_gn_java"
  config_override=build/config/default.json
  config_to_gn_args=""

  if [ -f "${ROOT_DIR}"/"${build_dir}""${BUILD_CONFIG_NAME}" ]; then
    rm "${ROOT_DIR}"/"${build_dir}""${BUILD_CONFIG_NAME}"
  fi
  # Generate build_config.gn
  if ! [ -d "${CONFIG_AUTO_GEN_DIR}" ];then
      mkdir "${CONFIG_AUTO_GEN_DIR}"
  fi

  result=python build/config_to_gn.py \
     -o "${ROOT_DIR}"/"${build_dir}""${BUILD_CONFIG_NAME}" \
     -d ${CONFIG_AUTO_GEN_DIR} \
     -i ${config_override} ${config_to_gn_args}
  if [ $? -ne 0 ]; then
    echo -e "Failed to execute build/config_to_gn.py, see errors above."
    exit 1
  fi
  buildargs="${buildargs}
    ohos_nweb_ex_config_name=\"//${build_dir}${BUILD_CONFIG_NAME}\"
    "
fi

cd src

time_start_for_build=`date +%s`
time_start_for_gn=$time_start_for_build

if [ $buildgn = 1 ]; then
  echo "generating args list: $buildargs $GN_ARGS"
  third_party/depot_tools/gn gen $build_dir --args="$buildargs $buildarg_cpu $buildarg_musl $build_sysroot $build_product_name $GN_ARGS symbol_level=$SYMBOL_LEVEL"
fi
time_end_for_gn=`date +%s`

third_party/depot_tools/ninja -C $build_dir -j$buildcount ${build_target}
time_end_for_build=`date +%s`

time_format() {
  hours=$((($1 - $2) / 3600))
  minutes=$((($1 - $2) % 3600 / 60))
  seconds=$((($1 - $2) % 60))
}

time_format $time_end_for_gn $time_start_for_gn
printf "\n\e[32mTime for gn  : %dH:%dM:%dS \e[0m\n" $hours $minutes $seconds
time_format $time_end_for_build $time_end_for_gn
printf "\e[32mTime for build : %dH:%dM:%dS \e[0m\n" $hours $minutes $seconds
time_format $time_end_for_build $time_start_for_build
printf "\e[32mTime for Total : %dH:%dM:%dS \e[0m\n\n" $hours $minutes $seconds

echo "build done"
