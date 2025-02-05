#!/bin/bash
# Copyright 2020 The MediaPipe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =========================================================================
#
# Script to build/run all MediaPipe desktop example apps (with webcam input).
#
# CPU options: [arm64/m1/M1, x86_64, i386]
# To only build "face_detection" app and store it in out_dir for MacOS with M1 CPU:
#   $ ./build_desktop_examples.sh -c m1 -d out_dir -a face_detection
#   Omitting -d and the associated directory saves all generated apps in the
#   current directory.
# To build and run all apps and store them in out_dir for MacOS with M1 CPU:
#   $ ./build_desktop_examples.sh -c m1 -d out_dir
#   Omitting -d and the associated directory saves all generated apps in the
#   current directory.
# To build all apps and store them in out_dir for MacOS with x86_64 CPU:
#   $ ./build_desktop_examples.sh -c x86_64 -d out_dir -b
#   Omitting -d and the associated directory saves all generated apps in the
#   current directory.
# To run all apps already stored in out_dir:
#   $ ./build_desktop_examples.sh -d out_dir -r
#   Omitting -d and the associated directory assumes all apps are in the current
#   directory.

set -e

out_dir="."
build_only=false
run_only=false
# cpu options: [arm64/m1/M1, x86_64, i386]
# corresponding bazel cpu options: [darwin_arm64, darwin_x86_64, darwin]
cpu="arm64"
app_dir="mediapipe/examples/desktop"
app_name=""
bin_dir="bazel-bin"

while [[ -n $1 ]]; do
  case $1 in
    -d)
      shift
      out_dir=$1
      ;;
    -c | --cpu)
      shift
      cpu=$1
      ;;
    -a | --app)
      shift
      app_name=$1
      ;;
    -b)
      build_only=true
      ;;
    -r)
      run_only=true
      ;;
    *)
      echo "Unsupported input argument $1."
      exit 1
      ;;
  esac
  shift
done

case $cpu in
    x86_64 | i386)
      cpu="darwin_$cpu"
      ;;
    arm64 | m1 | M1)
      cpu="darwin_arm64"
      ;;
    *)
      echo "Unsupported cpu argument $1."
      exit 1
      ;;
  esac

echo "app_dir: $app_dir"
echo "out_dir: $out_dir"
echo "cpu: $cpu"
echo "app_name: $app_name"

declare -a default_bazel_flags=(build -c opt --define MEDIAPIPE_DISABLE_GPU=1 --cpu $cpu)
declare -a bazel_flags

if [[ ! -z "${app_name}" ]]; then
  echo "Only build app: ${app_dir}/${app_name}"
  declare -a apps=("${app_dir}/${app_name}")
else
  echo "Build all available apps under $app_dir"
  apps="${app_dir}/*"
fi

for app in ${apps}; do
  if [[ -d "${app}" ]]; then
    target_name=${app##*/}
    if [[ "${target_name}" == "autoflip" ||
          "${target_name}" == "hello_world" ||
          "${target_name}" == "media_sequence" ||
          "${target_name}" == "object_detection_3d" ||
          "${target_name}" == "template_matching" ||
          "${target_name}" == "youtube8m" ]]; then
      echo "Skip ${target_name}"
      continue
    fi
    target="${app}:${target_name}_cpu"

    echo "=== Target: ${target}"

    if [[ $run_only == false ]]; then
      bazel_flags=("${default_bazel_flags[@]}")
      bazel_flags+=(${target})

      bazel "${bazel_flags[@]}"
      cp -f "${bin_dir}/${app}/"*"_cpu" "${out_dir}"
    fi
    if [[ $build_only == false ]]; then
      if  [[ ${target_name} == "object_tracking" ]]; then
        graph_name="tracking/object_detection_tracking"
      elif [[ ${target_name} == "upper_body_pose_tracking" ]]; then
        graph_name="pose_tracking/upper_body_pose_tracking"
      else
        graph_name="${target_name}/${target_name}"
      fi
      if [[ ${target_name} == "holistic_tracking" ||
            ${target_name} == "iris_tracking" ||
            ${target_name} == "pose_tracking" ||
            ${target_name} == "upper_body_pose_tracking" ]]; then
        graph_suffix="cpu"
      else
        graph_suffix="desktop_live"
      fi
      GLOG_logtostderr=1 "${out_dir}/${target_name}_cpu" \
        --calculator_graph_config_file=mediapipe/graphs/"${graph_name}_${graph_suffix}.pbtxt"
    fi
  fi
done
