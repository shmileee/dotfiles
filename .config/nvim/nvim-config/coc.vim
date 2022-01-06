" Use <C-l> for trigger snippet expand.
imap <C-l> <Plug>(coc-snippets-expand)

nmap <Leader>sp <Plug>(coc-fix-current)

" Symbol renaming.
nmap <Leader>rn <Plug>(coc-rename)

" Use K to show documentation in preview window.
nnoremap <silent>K :call <SID>show_documentation()<CR>

nmap <Leader>a <Plug>(coc-codeaction-selected)

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
