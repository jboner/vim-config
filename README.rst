My (@jboner) Vim config
#######################

Setup Vim for Scala development and more.

It has some pretty nice plugins and custom bindings/functions.

Modules
=======

Here is a list of the main modules, but check out ./vimrc for details.

- Scala
- YankRing
- NERDTree
- NERDCommenter
- reStructuredText
- TagBar
- Surround
- SuperTab
- SnipMate
- Session
- Project
- PeepOpen
- MRU
- LustyJuggler
- LustyExplorer
- FuzzyFinder
- Conque
- Ack
- Theme pack
- ZoomWin
- Git

Also check out the vim-custom-cheatsheet.txt for a reference. 

Install
=======

1. Run `./install.sh` to install the config to `~/.vim_runtime`
2. Create a `.vimrc` in your home directory loading the `vimrc` in the root dir.   
fun! MySys()
  return "$1"
endfun
set runtimepath=~/.vim_runtime,~/.vim_runtime/after,\$VIMRUNTIME
source ~/.vim_runtime/vimrc
helptags ~/.vim_runtime/doc
