{
  lib,
  fetchpatch,
  python3,
  fetchPypi,
  postfix,
  lynx,
  nixosTests,
}:

with python3.pkgs;

buildPythonPackage rec {
  pname = "mailman";
  version = "3.3.9";
  pyproject = true;

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-GblXI6IwkLl+V1gEbMAe1baVyZOHMaYaYITXcTkp2Mo=";
  };

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies = with python3.pkgs; [
    aiosmtpd
    alembic
    authheaders
    click
    dnspython
    falcon
    flufl-bounce
    flufl-i18n
    flufl-lock
    gunicorn
    lazr-config
    passlib
    python-dateutil
    requests
    sqlalchemy
    standard-nntplib
    zope-component
    zope-configuration
  ];

  checkInputs = [
    sphinx
  ];

  patches = [
    (fetchpatch {
      url = "https://gitlab.com/mailman/mailman/-/commit/4b206e2a5267a0e17f345fd7b2d957122ba57566.patch";
      sha256 = "06axmrn74p81wvcki36c7gfj5fp5q15zxz2yl3lrvijic7hbs4n2";
    })
    (fetchpatch {
      url = "https://gitlab.com/mailman/mailman/-/commit/9613154f3c04fa2383fbf017031ef263c291418d.patch";
      sha256 = "0vyw87s857vfxbf7kihwb6w094xyxmxbi1bpdqi3ybjamjycp55r";
    })
    (fetchpatch {
      name = "python-3.13.patch";
      url = "https://gitlab.com/mailman/mailman/-/commit/685d9a7bdbd382d9e8d4a2da74bd973e93356e05.patch";
      hash = "sha256-KCXVP+5zqgluUXQCGmMRC+G1hEDnFBlTUETGpmFDOOk=";
    })
    ./log-stderr.patch
  ];

  postPatch = ''
    substituteInPlace src/mailman/config/postfix.cfg \
      --replace /usr/sbin/postmap ${postfix}/bin/postmap
    substituteInPlace src/mailman/config/schema.cfg \
      --replace /usr/bin/lynx ${lynx}/bin/lynx
  '';

  # Mailman assumes that those scripts in $out/bin are Python scripts. Wrapping
  # them in shell code breaks this assumption. Use the wrapped version (see
  # wrapped.nix) if you need the CLI (rather than the Python library).
  #
  # This gives a properly wrapped 'mailman' command plus an interpreter that
  # has all the necessary search paths to execute unwrapped 'master' and
  # 'runner' scripts.
  dontWrapPythonPrograms = true;

  passthru.tests = { inherit (nixosTests) mailman; };

  meta = {
    homepage = "https://www.gnu.org/software/mailman/";
    description = "Free software for managing electronic mail discussion and newsletter lists";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ qyliss ];
  };
}
