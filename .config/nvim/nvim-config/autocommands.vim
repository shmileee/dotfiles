" -----------------------------------------------------------------------------
" Basic autocommands
" -----------------------------------------------------------------------------

" Wrap text under cursor with double curly braces (e.g., for Jinja variables).
" Binds to ysiwj (106 = char2nr('j'))
" https://stackoverflow.com/questions/52330006/vim-binding-to-wrap-word-under-cursor-in-double-curly-braces
autocmd FileType ansible,yaml,j2 let b:surround_106 = "{{ \r }}"

" Auto-resize splits when Vim gets resized.
autocmd VimResized * wincmd =

" Update a buffer's contents on focus if it changed outside of Vim.
" au FocusGained,BufEnter * :checktime

" Unset paste on InsertLeave.
autocmd InsertLeave * silent! set nopaste

" Make sure all types of requirements.txt files get syntax highlighting.
autocmd BufNewFile,BufRead requirements*.txt set syntax=python

" Make sure .aliases, .bash_aliases and similar files get syntax highlighting.
autocmd BufNewFile,BufRead .*aliases set syntax=sh

" Ensure tabs don't get converted to spaces in Makefiles.
autocmd FileType make setlocal noexpandtab

" Only show the cursor line in the active buffer.
augroup CursorLine
    au!
    au VimEnter,WinEnter,BufWinEnter * setlocal cursorline
    au WinLeave * setlocal nocursorline
augroup END

" Make sure Kubernetes yaml files end up being set as helm files.
au BufNewFile,BufRead *.{yaml,yml} if getline(1) =~ '^apiVersion:' || getline(2) =~ '^apiVersion:' | setlocal filetype=helm | endif

" Highlight Jenkinsfile syntax as grovy
au BufNewFile,BufRead Jenkinsfile setf groovy

autocmd FileType gitcommit setlocal spell

au BufRead,BufNewFile *.md setlocal textwidth=80
