if exists('g:loaded_narrow') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

hi def link NarrowHeader  Identifier
hi def link NarrowMatch   Number

" command to run our plugin
command! Narrow lua require'narrow'.narrow()

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_narrow = 1
