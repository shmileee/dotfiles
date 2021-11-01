" cSpell:words Lfcd Goyo
nmap <Leader><tab> :bp<cr>
nmap <Leader>b :Buffers<cr>
nmap <Leader>] :bn<cr>
nmap <Leader>[ :bp<cr>
nmap <Leader>f :LfNewTab<cr>
nmap <Leader>h :HopWord<cr>
nmap <Leader>l :HopLine<cr>
nmap <Leader>m :MaximizerToggle!<cr>

" UndoTree
nnoremap <Leader>u :UndotreeShow<CR>

" Press * to search for the term under the cursor or a visual selection and
" then press a key below to replace all instances of it in the current file.
nnoremap <Leader>r :%s///g<Left><Left>
nnoremap <Leader>rc :%s///gc<Left><Left><Left>

" The same as above but instead of acting on the whole file it will be
" restricted to the previously visually selected range. You can do that by
" pressing *, visually selecting the range you want it to apply to and then
" press a key below to replace all instances of it in the current selection.
xnoremap <Leader>r :s///g<Left><Left>
xnoremap <Leader>rc :s///gc<Left><Left><Left>

" Clear search highlights.
map <Leader><Space> :let @/=''<CR>

" Edit Vim config file in a new tab.
map <Leader>ev :tabnew $MYVIMRC<CR>

" Source Vim config file.
map <Leader>sv :source $MYVIMRC<CR>

" Search current token in Dash
nmap <silent> <Leader>d <Plug>DashSearch

" Automatically fix the last misspelled word and jump back to where you were.
"   Taken from this talk: https://www.youtube.com/watch?v=lwD8G1P52Sk
nnoremap <Leader>sp :normal! mz[s1z=`z<CR>
