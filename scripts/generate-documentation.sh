#!/bin/sh
# Generates the documentation of the package as a static site in docs/,
# which GitHub Pages publishes at https://erikt.github.io/MiamiStateMachine/.
# Run it from anywhere, and commit docs/ with the release it documents.
set -eu

cd "$(dirname "$0")/.."
rm -rf docs

swift package --allow-writing-to-directory docs generate-documentation \
    --target MiamiStateMachine \
    --target MiamiUI \
    --target MiamiDiagrams \
    --target MiamiMacros \
    --enable-experimental-combined-documentation \
    --transform-for-static-hosting \
    --hosting-base-path MiamiStateMachine \
    --output-path docs

# The root of the site has no page of its own, so it leads to the documentation.
cat > docs/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>MiamiStateMachine</title>
<meta http-equiv="refresh" content="0; url=documentation/">
<link rel="canonical" href="documentation/">
</head>
<body>
<p><a href="documentation/">The documentation of MiamiStateMachine</a></p>
</body>
</html>
HTML

# Published as it is, without Jekyll.
touch docs/.nojekyll
