#!/bin/sh

jazzy \
    --clean \
    --author "Károly Lőrentey" \
    --author_url "https://twitter.com/lorentey" \
    --github_url https://github.com/lorentey/GlueKit \
    --github-file-prefix https://github.com/lorentey/GlueKit/tree/master \
    --module-version 1.0.0-alpha.1 \
    --xcodebuild-arguments -scheme,GlueKit \
    --module GlueKit \
    --root-url https://lorentey.github.io/GlueKit/reference/ \
    --output jazzy/output \
    --swift-version 2.1.1

#--template-directory jazzy/templates \
