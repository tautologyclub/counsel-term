# counsel-term.el
Some hacky but extremely convenient functions for making life inside term-mode
easier.  All of them make use of two things: first, the excellent 'ivy-read' API
and second, the fact that you can send raw control characters such representing
C-k, C-u, etc to your terminal using 'term-send-raw-string'.

# Summary
## counsel-term-history
A simple utility that completing-reads your #~/.bash_history (or whatever other
file you want, really) and sends the #selected candidate to the terminal.  To
get going, bind 'counsel-term-history #to some nice stroke in your
term-mode-map, C-r comes quite naturally to mind.

## counsel-term-cd
counsel-term-cd -- Recursively find a directory, starting at $PWD, and cd to it.

## counsel-term-ff
counsel-term-ff -- Find file with completion in current dir.  If it's a
directory, cd to it and call counsel-term-ff again.  If not, open it using
find-file.  The recursion is really badly implemented ATM using elisp sleep
which results in a flickering minibuffer.  Advice appreciated :)

## Note
This package has no association with counsel or ivy apart from using the ivy api
and kinda feeling lika a counsel package.  The author admits to a slighy
fanboy-ism towards their creator however -- support him on Patreon!  More
instructions on his site, oremacs.com.
