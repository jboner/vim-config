" exec scriptmanager#DefineAndBind('s:c','g:ensime','{}')
if !exists('g:ensime') | let g:ensime = {} | endif | let s:c = g:ensime

" start and connect to ensime server
command! -nargs=0 Ensime call ensime#StartEnsimeServer()
command! -nargs=0 EnsimeConnectionInfo call ensime#Request(["swank:connection-info"])
command! -nargs=0 EnsimeRepl call ensime#Request(["swank:repl-config"])
command! -nargs=0 EnsimeTypeAtCursor call ensime#TypeAtCursor('')
command! -nargs=0 EnsimeInspectAtCursor call ensime#InspectAtCursor()
command! -nargs=1 EnsimeInspectTypeById call ensime#InspectTypeById(<f-args>)
command! -nargs=0 EnsimeDefinition call ensime#TypeAtCursor('goto')
command! -nargs=* -complete=file EnsimeFormatSource call ensime#FormatSource(empty([<f-args>]) ? [expand('%')] : [<f-args>] )

" this will be called automatically for you!
command! -nargs=0 EnsimeConnect call ensime#Connect()
" you don't have to call this because each buffer will be updated on buf write
command! -nargs=0 EnsimeTypecheckAll   call ensime#Request(["swank:typecheck-all"])

let s:c.prevent_typecheck = 0
augroup ENSIME
  au!
  autocmd BufWritePost *.scala if !s:c.prevent_typecheck | call ensime#TypecheckFile() | endif
  autocmd BufRead,BufNewFile .ensime  setlocal ft=dot_ensime_config
augroup end
