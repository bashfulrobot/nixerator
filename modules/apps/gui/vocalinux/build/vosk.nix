{
  lib,
  python3Packages,
  autoPatchelfHook,
  stdenv,
}:

python3Packages.buildPythonPackage rec {
  pname = "vosk";
  version = "0.3.45";
  format = "wheel";

  src = python3Packages.fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "manylinux_2_12_x86_64.manylinux2010_x86_64";
    hash = "sha256-JeAlCTxDmdcnj1Q1aO2MxUYKw6S/SMI2c6zh4l0mYZ8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  propagatedBuildInputs = with python3Packages; [
    cffi
    requests
    tqdm
    srt
    websockets
  ];

  # Skip tests - they require models to be downloaded
  doCheck = false;

  pythonImportsCheck = [ "vosk" ];

  meta = with lib; {
    description = "Offline speech recognition API";
    homepage = "https://alphacephei.com/vosk/";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
