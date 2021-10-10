## surround.vim

motion  | description
------------- | -------------
cs{' | { test } > 'test'
ds" | "test" > test
yss" | test > "test" (whole line)
ysiwj | ansible_string > {{ ansible_string }}


## fzf.vim

hotkey  | description
------------- | -------------
ctrl + P | search file in current directory
ctrl + T | open file in new tab
ctrl + V | open file in new vertical split
shift + tab | select file
alt +A | select all files


## general hotkeys

hotkey  | description
------------- | -------------
F5 | toggle spell check
F6 | toggle absolute numbers
F7 | toggle white space characters
Leader + ev | edit ~/.vimrc
Leader + R | replace all occurrences in current project
Leader + r | replace all occurrences in current file
Leader + c | toggle quick fix list
Leader + l | toggle search over lines of current file
Leader + sp | fix last misspelled word
ctrl + wo | close all windows except current
ctrl + o | jump previous
ctrl + i | jump next
ctrl + ^ | switch between 2 most recent files
Leader + d | search for current word in Dash
!norm @q | replay macro `q` on visually selected lines
shift + J/K | move visually selected lines DOWN/UP
