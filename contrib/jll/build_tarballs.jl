# Self-hosted build: uses upstream's pinned vendored-dependency configuration.
# This recipe does not claim official Yggdrasil acceptance or change upstream licensing.
using BinaryBuilder

name = "PALSParserCpp"
version = v"0.1.0"
sources = [
    GitSource("https://github.com/pals-project/PALSParserCpp.git", "949c29462204c46d0c520e41dea0c582a8adcb8b"),
    GitSource("https://github.com/biojppm/rapidyaml.git", "119b6042064d3828819e428e32e5a0f3035d5643"),
    # BinaryBuilder GitSource does not recursively populate Git submodules.
    GitSource("https://github.com/biojppm/c4core.git", "18543ed436cd32a375057ba4d9b0a7d9c5d60584"),
    GitSource("https://github.com/biojppm/cmake.git", "1e65b7b29e872ccc1df7ea3cb8091bfb56b24147"),
    GitSource("https://github.com/biojppm/debugbreak.git", "328e4abca3384cbd0a69e70f263cc7b2794bff09"),
    GitSource("https://github.com/fastfloat/fast_float.git", "eb9ab42c0aa86d3cc41871ba7306527d95077b3b"),
    GitSource("https://github.com/PCRE2Project/pcre2.git", "6ae58beca071f13ccfed31d03b3f479ab520639b"),
    GitSource("https://github.com/pals-project/AtomicAndPhysicalConstantsCLib.git", "7d16dd842f1f50cdda9e0f1da86ee56a5a2b6232"),
    DirectorySource("./bundled"),
]

script = raw"""
# Restore the exact submodule trees recorded by the pinned rapidyaml revision.
cp -a ${WORKSPACE}/srcdir/c4core/. ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/
cp -a ${WORKSPACE}/srcdir/cmake/. ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/cmake/
cp -a ${WORKSPACE}/srcdir/debugbreak/. ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/src/c4/ext/debugbreak/
cp -a ${WORKSPACE}/srcdir/fast_float/. ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/src/c4/ext/fast_float/
test -f ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/cmake/c4Project.cmake
cd ${WORKSPACE}/srcdir/PALSParserCpp
atomic_patch -p1 ${WORKSPACE}/srcdir/patches/packaging.patch
cmake -S . -B build \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_INSTALL_PREFIX=${prefix} -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF -DPALS_BUILD_EXAMPLES=OFF \
    -DFETCHCONTENT_SOURCE_DIR_RAPIDYAML=${WORKSPACE}/srcdir/rapidyaml \
    -DFETCHCONTENT_SOURCE_DIR_PCRE2=${WORKSPACE}/srcdir/pcre2 \
    -DFETCHCONTENT_SOURCE_DIR_APC=${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib
cmake --build build --target PALSParserCpp --parallel ${nproc}
cmake --install build --component PALSParserCpp
install_license ${WORKSPACE}/srcdir/notices/NOTICE.txt
install -Dvm 644 ${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib/LICENSE ${prefix}/share/licenses/PALSParserCpp/APC-LICENSE
install -Dvm 644 ${WORKSPACE}/srcdir/rapidyaml/LICENSE.txt ${prefix}/share/licenses/PALSParserCpp/rapidyaml-LICENSE.txt
install -Dvm 644 ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/LICENSE.txt ${prefix}/share/licenses/PALSParserCpp/c4core-LICENSE.txt
install -Dvm 644 ${WORKSPACE}/srcdir/rapidyaml/ext/c4core/LICENSE-BOOST.txt ${prefix}/share/licenses/PALSParserCpp/c4core-LICENSE-BOOST.txt
install -Dvm 644 ${WORKSPACE}/srcdir/pcre2/LICENCE ${prefix}/share/licenses/PALSParserCpp/PCRE2-LICENCE
"""

platforms = expand_cxxstring_abis(supported_platforms())
products = [LibraryProduct("libPALSParserCpp", :libPALSParserCpp)]
dependencies = [Dependency("CompilerSupportLibraries_jll"; compat="1")]
# C++17 source requires GCC 7 or later.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.10", preferred_gcc_version=v"7")
