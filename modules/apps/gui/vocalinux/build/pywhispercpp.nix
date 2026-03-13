{
  lib,
  python3Packages,
  autoPatchelfHook,
  stdenv,
  vulkan-loader,
}:

python3Packages.buildPythonPackage rec {
  pname = "pywhispercpp";
  version = "1.4.1";
  format = "wheel";

  src = python3Packages.fetchPypi {
    inherit pname version format;
    dist = "cp313";
    python = "cp313";
    abi = "cp313";
    platform = "manylinux_2_27_x86_64.manylinux_2_28_x86_64";
    hash = "sha256-3B3g1GbtvIMUf09pzaycAy3apV6lprlsR5NNLlqkTmw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    vulkan-loader
  ];

  propagatedBuildInputs = with python3Packages; [
    numpy
    platformdirs
    requests
    tqdm
  ];

  doCheck = false;

  pythonImportsCheck = [ "pywhispercpp" ];

  meta = with lib; {
    description = "Python bindings for whisper.cpp";
    homepage = "https://github.com/abreham-atlaw/pywhispercpp";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
