call plug#begin()
source $HOME/.config/nvim/nvim-config/plugins.vim
call plug#end()

source $HOME/.config/nvim/nvim-config/general.vim
source $HOME/.config/nvim/nvim-config/theme.vim
source $HOME/.config/nvim/nvim-config/init.lua
" slows things down
" source $HOME/.config/nvim/nvim-config/coc.vim
source $HOME/.config/nvim/nvim-config/mappings.vim
source $HOME/.config/nvim/nvim-config/autocommands.vim
source $HOME/.config/nvim/nvim-config/functions.vim
source $HOME/.config/nvim/nvim-config/quick-scope.vim
source $HOME/.config/nvim/nvim-config/goyo.vim
source $HOME/.config/nvim/nvim-config/fzf.vim
source $HOME/.config/nvim/nvim-config/start-screen.vim

let mapleader=" "
source $HOME/.config/nvim/nvim-config/leader.vim

" Miscellaneous
command! LF FloatermNew lf
let g:airline#extensions#tabline#enabled=1
let g:vim_markdown_folding_disabled = 1

" .............................................................................
" airblade/vim-rooter
" .............................................................................
let g:rooter_patterns = ['.git']

" .............................................................................
" ptzz/lf.vim
" .............................................................................
let g:lf_replace_netrw = 1 " Open lf when vim opens a directory
let g:lf_width = 0.9
let g:lf_height = 0.7

" .............................................................................
" ntpeters/vim-better-whitespace
" .............................................................................
let g:strip_whitespace_confirm=0
let g:strip_whitelines_at_eof=1
let g:strip_whitespace_on_save=1

" Write all buffers before navigating from Vim to tmux pane
let g:tmux_navigator_save_on_switch = 2

" .............................................................................
" rizzatti/dash.vim"
" .............................................................................
let g:dash_activate=1

" Use a line cursor within insert mode and a block cursor everywhere else.
"
" Reference chart of values:
"   Ps = 0  -> blinking block.
"   Ps = 1  -> blinking block (default).
"   Ps = 2  -> steady block.
"   Ps = 3  -> blinking underline.
"   Ps = 4  -> steady underline.
"   Ps = 5  -> blinking bar (xterm).
"   Ps = 6  -> steady bar (xterm).
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"
