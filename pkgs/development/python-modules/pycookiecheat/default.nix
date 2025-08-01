{
  lib,
  stdenv,
  buildPythonPackage,
  cryptography,
  fetchFromGitHub,
  keyring,
  pytestCheckHook,
  pythonOlder,
  playwright,
  setuptools,
  setuptools-scm,
}:

buildPythonPackage rec {
  pname = "pycookiecheat";
  version = "0.8.0";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "n8henrie";
    repo = "pycookiecheat";
    tag = "v${version}";
    hash = "sha256-jOyTfh2ZhKW/pMU7T5tfxaM0l/g59N+mirnbc0FLPbQ=";
  };

  pythonRelaxDeps = [
    "cryptography"
    "keyring"
  ];

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    cryptography
    keyring
  ];

  nativeCheckInputs = [
    playwright
    pytestCheckHook
  ];

  pythonImportsCheck = [ "pycookiecheat" ];

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  disabledTests = [
    # Tests want to use playwright executable
    "test_fake_cookie"
    "test_firefox_cookies"
    "test_firefox_get_default_profile"
    "test_firefox_no_cookies"
    "test_load_firefox_cookie_db"
    "test_no_cookies"
    "test_warns_for_string_browser"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ "test_slack_config" ];

  meta = with lib; {
    description = "Borrow cookies from your browser's authenticated session for use in Python scripts";
    homepage = "https://github.com/n8henrie/pycookiecheat";
    changelog = "https://github.com/n8henrie/pycookiecheat/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [
      fab
      n8henrie
    ];
  };
}
