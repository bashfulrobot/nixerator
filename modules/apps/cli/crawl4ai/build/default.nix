{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
  playwright-driver,
  versions,
}:

python3Packages.buildPythonApplication rec {
  pname = "crawl4ai";
  inherit (versions.cli.crawl4ai) version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "unclecode";
    repo = "crawl4ai";
    tag = "v${version}";
    inherit (versions.cli.crawl4ai) hash;
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    aiofiles
    aiohttp
    aiosqlite
    anyio
    beautifulsoup4
    chardet
    click
    cssselect
    fake-useragent
    httpx
    humanize
    lark
    litellm
    lxml
    nltk
    numpy
    pillow
    playwright
    playwright-stealth
    pydantic
    pyopenssl
    pyyaml
    rank-bm25
    requests
    rich
    shapely
    snowballstemmer
    tiktoken
    xxhash
  ];

  # setup.py creates ~/.crawl4ai at parse time; redirect to $TMPDIR during build.
  # The CRAWL4_AI_BASE_DIRECTORY env var is respected by setup.py.
  preBuild = ''
    export CRAWL4_AI_BASE_DIRECTORY="$TMPDIR"
  '';

  preConfigure = ''
    export CRAWL4_AI_BASE_DIRECTORY="$TMPDIR"
  '';

  nativeBuildInputs = [ makeWrapper ];

  # Wrap crwl to find Nix-provided Chromium and skip browser downloads
  postInstall = ''
    wrapProgram $out/bin/crwl \
      --set PLAYWRIGHT_BROWSERS_PATH "${playwright-driver.browsers}" \
      --set CRAWL4AI_MODE "api"

    # Wrap other entry points too
    for bin in crawl4ai-setup crawl4ai-doctor crawl4ai-migrate crawl4ai-download-models; do
      if [ -f "$out/bin/$bin" ]; then
        wrapProgram "$out/bin/$bin" \
          --set PLAYWRIGHT_BROWSERS_PATH "${playwright-driver.browsers}" \
          --set CRAWL4AI_MODE "api"
      fi
    done
  '';

  # Tests require network access
  doCheck = false;

  # patchright and alphashape are optional — crawl4ai falls back gracefully
  pythonRelaxDeps = [
    "lxml"
    "snowballstemmer"
    "patchright"
    "alphashape"
  ];
  pythonRemoveDeps = [
    "patchright"
    "alphashape"
  ];

  meta = {
    description = "LLM-friendly web crawling and scraping";
    homepage = "https://github.com/unclecode/crawl4ai";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "crwl";
  };
}
