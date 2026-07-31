#!/bin/bash -e
## Build Mixxx
mkdir -p ${BASE_DIR}/.ccache/
mkdir -p "${ROOTFS_DIR}/ccache"
mount --bind ${BASE_DIR}/.ccache  "${ROOTFS_DIR}/ccache"
on_chroot << EOF
    git clone --depth 1 --branch "${MIXXX_REF}" https://github.com/mixxxdj/mixxx.git /code/
    cd /code/
    tools/debian_buildenv.sh setup
    git rev-parse HEAD > /opt/mixxx.version
    git describe --tags --always > /opt/mixxx.tag
    export CCACHE_DIR=/ccache
    ccache -M 10G
    export CCACHE_NOCOMPRESS="true"
    export CTEST_PARALLEL_LEVEL="$(nproc)"
    export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc)"
    export PATH="$HOME/.local/bin:$PATH"
    export GTEST_COLOR="1"
    export CTEST_OUTPUT_ON_FAILURE="1"
    export QT_QPA_PLATFORM="offscreen"
    mkdir -p build && cd build
    cmake \
      -DKEYFINDER=ON -DFFMPEG=ON -DMAD=ON -DMODPLUG=ON -DWAVPACK=ON -DBULK=ON \
      -DCMAKE_INSTALL_PREFIX=/usr/ -S /code -B /code/build
    cmake --build /code/build --target install
    ccache -s
    cpack -G DEB
EOF

unmount "${BASE_DIR}/.ccache"
mkdir -p "$DEPLOY_DIR"
cp ${ROOTFS_DIR}/code/build/*.deb "$DEPLOY_DIR/"
if [ "${PACKAGE_ONLY}" = "1" ]; then
    cp "${ROOTFS_DIR}/opt/mixxx.version" "${DEPLOY_DIR}/mixxx.version"
    cp "${ROOTFS_DIR}/opt/mixxx.tag" "${DEPLOY_DIR}/mixxx.tag"
    dpkg-deb -I "${DEPLOY_DIR}"/*.deb > "${DEPLOY_DIR}/mixxx-package.info"
fi
rm -rf ${ROOTFS_DIR}/code/
