" -----------------------------------------------------------------------------
" Basic mappings
" -----------------------------------------------------------------------------

" Yank to end of line
nnoremap Y yg_

" Center next search results
" cspell:disable
nnoremap n nzzzv
nnoremap N Nzzzv
" cspell:enable

" Undo break points
inoremap , ,<c-g>u

" Jumplist mutation
nnoremap <expr> k (v:count > 5 ? "m'" . v:count : "") . 'k'
nnoremap <expr> j (v:count > 5 ? "m'" . v:count : "") . 'j'

" Moving text
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" better use of arrow keys, number increment/decrement
nnoremap <up> <C-a>
nnoremap <down> <C-x>
nnoremap <silent> Q <nop>

" https://vim.fandom.com/wiki/Insert_newline_without_entering_insert_mode
nnoremap o o<Esc>
nnoremap O O<Esc>

" Cycle through splits.
nnoremap <S-Tab> <C-w>w

" Type a replacement term and press . to repeat the replacement again. Useful
" for replacing a few instances of the term (comparable to multiple cursors).
nnoremap <silent> s* :let @/='\<'.expand('<cword>').'\>'<CR>cgn
xnoremap <silent> s* "sy:let @/=@s<CR>cgn

" Prevent x from overriding what's in the clipboard.
noremap x "_x
noremap X "_x

" Prevent selecting and pasting from overwriting what you originally copied.
xnoremap p pgvy

" Keep cursor at the bottom of the visual selection after you yank it.
vmap y ygv<Esc>

" Toggle spell check.
map <F1> :setlocal spell!<CR>

" Toggle relative line numbers and regular line numbers.
nmap <F2> :set invrelativenumber<CR>

" Run Autoformat on whole file
nmap <F4> :Autoformat<CR>

" Better line concatenation.
nnoremap J mzJ`z

" Open URLs under cursor.
nmap gn <Plug>(openbrowser-smart-search)
vmap gn <Plug>(openbrowser-smart-search)

" Navigate with CTRL+J / CTRL+J in completion mode.
inoremap <expr> <C-j> pumvisible() ? "\<C-N>" : "\<C-j>"
inoremap <expr> <C-k> pumvisible() ? "\<C-P>" : "\<C-k>"
