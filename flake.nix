{
  description = "Cross-compile Dropbear SSH for Android (aarch64-linux-android), statically linked";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        ndkBundle = pkgs.androidenv.androidPkgs.ndk-bundle;

        buildTools = with pkgs; [
          gnumake
          autoconf
          autoconf-archive
          automake
          libtool
          m4
          pkg-config
          file
          which
          perl
          ndkBundle
        ];

        apiLevel = "21";
        targetTriple = "aarch64-linux-android";
        targetPrefix = "${targetTriple}${apiLevel}";

        configureCache = pkgs.writeText "dropbear-android-config.cache" ''
          # crypt() is absent from bionic at API 21.
          ac_cv_func_crypt=no
          ac_cv_search_crypt=no

          # bionic has no getusershell()/endusershell().
          ac_cv_func_getusershell=no
          ac_cv_func_endusershell=no
          ac_cv_func_setusershell=no

          # bionic gates openpty()/forkpty() behind __INTRODUCED_IN(23), so
          # they're absent at our min API level (21). Dropbear has a fallback
          # devpts/ptmx path that works on Android.
          ac_cv_search_openpty=no
          ac_cv_func_openpty=no
          ac_cv_func_forkpty=no

          # No shadow passwords on Android.
          ac_cv_header_shadow_h=no

          # utmp/wtmp machinery is absent on Android.
          ac_cv_func_utmpname=no
          ac_cv_func_utmpxname=no
          ac_cv_func_updwtmp=no
          ac_cv_func_updwtmpx=no
          ac_cv_func_login_tty=no

          # No PAM on Android by default.
          ac_cv_header_security_pam_appl_h=no
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = buildTools;
          shellHook = ''
            # source.properties is the NDK's manifest file and only lives at
            # the top level of an NDK install — unlike ndk-build (which has a
            # copy under build/) and toolchains/ (which also appears under
            # build/core/), this marker uniquely identifies the NDK root.
            _sp="$(find -L '${ndkBundle}' -type f -name source.properties 2>/dev/null | head -n1)"
            if [ -z "$_sp" ]; then
              echo "ERROR: could not locate 'source.properties' under '${ndkBundle}'" >&2
              return 1
            fi
            export ANDROID_NDK_ROOT="$(dirname "$_sp")"
            export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
            export NDK_ROOT="$ANDROID_NDK_ROOT"
            export TOOLCHAIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
            export SYSROOT="$TOOLCHAIN/sysroot"
            export TARGET_TRIPLE="${targetTriple}"
            export TARGET_PREFIX="${targetPrefix}"
            export API_LEVEL="${apiLevel}"
            export CONFIG_SITE='${configureCache}'

            # Sanity-check that the prefixed clang actually exists before
            # exporting — gives a clearer error than the build script's
            # generic check.
            if [ ! -x "$TOOLCHAIN/bin/$TARGET_PREFIX-clang" ]; then
              echo "ERROR: $TOOLCHAIN/bin/$TARGET_PREFIX-clang not found" >&2
              echo "       The NDK at $ANDROID_NDK_ROOT doesn't have the expected toolchain layout." >&2
              return 1
            fi

            # These MUST be exported in shellHook (not as direct attrs) —
            # stdenv's setup.sh overwrites CC/AR/etc. otherwise.
            export CC="$TOOLCHAIN/bin/$TARGET_PREFIX-clang"
            export CXX="$TOOLCHAIN/bin/$TARGET_PREFIX-clang++"
            export AR="$TOOLCHAIN/bin/llvm-ar"
            export AS="$TOOLCHAIN/bin/$TARGET_PREFIX-as"
            export LD="$TOOLCHAIN/bin/ld.lld"
            export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
            export STRIP="$TOOLCHAIN/bin/llvm-strip"
            export READELF="$TOOLCHAIN/bin/llvm-readelf"
            export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"
            export PATH="$TOOLCHAIN/bin:$PATH"

            echo "[android-shell] NDK:      $ANDROID_NDK_ROOT"
            echo "[android-shell] CC:       $CC"
            echo "[android-shell] SYSROOT:  $SYSROOT"
          '';
        };
        devShells.cross = self.devShells.${system}.default;
      });
}
