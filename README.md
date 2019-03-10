tlug.jp: Tokyo Linux Users Group Website
========================================

This is a work in progress for the new version of <https://tlug.jp>,
the Tokyo Linux Users group website. It's intended to be statically
generated using [Hakyll].

The current developers/maintainers are Curt Sampson (`@0cjs`)
<cjs@cynic.net> and Jim Tittsler (`@jimt`) <jimt@onjapan.net>.


Building
--------

#### Automatic Build

`./Test` should build and test the site, installing [Haskell Stack]
if necessary.

#### Manual Build

Install [Haskell Stack], usually with one of the following:

    curl -sSL https://get.haskellstack.org/ | sh
    wget -qO- https://get.haskellstack.org/ | sh

The do a `stack build` in this directory to build the `site` tool that
builds the site. Once this is done, useful command for development of
the website itself are:

    # Build site into _site/ dir
    stack exec site build 

    # Start preview server and rebuild when source files change
    # This also builds `site.hs` as above, if it's out of date.
    stack exec site watch -- --host HOST --port PORT 

For the second command `--host` and `--port` are optional. The server
will not automatically load a page for the site or refresh changed pages.


Deployment
----------

For the moment this site is deployed to two locations on [Netlify].
Pushing new commits to the `master` branch on GitHub should trigger a
build and the results should soon be visible on:

- <https://tlug.netlify.com> using Jim's Netlify account.
- <https://cjs-tlug.netlify.com>> using cjs's Netlify account.

As we don't currently have an shared organization account on Netlify,
only the account owner can see the build logs. We'll be discussing
later what we can do about this.



<!-------------------------------------------------------------------->
[Hakyll]: https://jaspervdj.be/hakyll/
[Haskell Stack]: https://docs.haskellstack.org/
[Netlify]: https://www.netlify.com/