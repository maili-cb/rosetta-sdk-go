#!/bin/bash
# Copyright 2020 Coinbase, Inc.
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

OS="$(uname)"
case "${OS}" in
    'Linux')
        OS='linux'
        SED_IFLAG=(-i'')
        ;;
    'Darwin')
        OS='macos'
        SED_IFLAG=(-i '')
        ;;
    *)
        echo "Operating system '${OS}' not supported."
        exit 1
        ;;
esac

# Remove existing generated code
rm -rf models;
rm -rf client;

# Generate client + models code
docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}":/local openapitools/openapi-generator-cli generate \
  -i /local/spec.json \
  -g go \
  -t /local/templates/client \
  --additional-properties packageName=models\
  -o /local/gen;

# Remove unnecessary files
mv gen/README.md .;
mv -n gen/go.mod .;
rm gen/go.mod;
rm gen/go.sum;
rm -rf gen/api;
rm -rf gen/docs;
rm gen/git_push.sh;
rm gen/.travis.yml;
rm gen/.gitignore;
rm gen/.openapi-generator-ignore;
rm -rf gen/.openapi-generator;

# Fix linting issues
sed "${SED_IFLAG[@]}" 's/Api/API/g' gen/*;
sed "${SED_IFLAG[@]}" 's/Json/JSON/g' gen/*;
sed "${SED_IFLAG[@]}" 's/Id /ID /g' gen/*;
sed "${SED_IFLAG[@]}" 's/Url/URL/g' gen/*;

# Remove special characters
sed "${SED_IFLAG[@]}" 's/&#x60;//g' gen/*;
sed "${SED_IFLAG[@]}" 's/\&quot;//g' gen/*;
sed "${SED_IFLAG[@]}" 's/\&lt;b&gt;//g' gen/*;
sed "${SED_IFLAG[@]}" 's/\&lt;\/b&gt;//g' gen/*;
sed "${SED_IFLAG[@]}" 's/<code>//g' gen/*;
sed "${SED_IFLAG[@]}" 's/<\/code>//g' gen/*;

# Fix slice containing pointers
sed "${SED_IFLAG[@]}" 's/\*\[\]/\[\]\*/g' gen/*;

# Fix misspellings
sed "${SED_IFLAG[@]}" 's/occured/occurred/g' gen/*;
sed "${SED_IFLAG[@]}" 's/cannonical/canonical/g' gen/*;
sed "${SED_IFLAG[@]}" 's/Cannonical/Canonical/g' gen/*;

# Format generated code
gofmt -w gen/;

# Move model files to models/
mkdir models;
mv gen/model_*.go models/;
for file in models/model_*.go; do
    mv "$file" "${file/model_/}"
done

# Change client files to correct package
sed "${SED_IFLAG[@]}" 's/package models/package client/g' gen/*;
mv gen client;

# Ensure license correct
make add-license;

# Ensure no long lines
make shorten-lines;

# Add server code
docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}":/local openapitools/openapi-generator-cli generate \
  -i /local/spec.json \
  -g go-server \
  -t /local/templates/server \
  --additional-properties packageName=server\
  -o /local/server_gen;

# Remove unnecessary files
rm -rf server_gen/api;
rm -rf server_gen/.openapi-generator;
rm server_gen/.openapi-generator-ignore;
rm server_gen/go.mod;
rm server_gen/main.go;
rm server_gen/README.md;
rm server_gen/Dockerfile;
mv server_gen/go/* server_gen/.;
rm -rf server_gen/go;
