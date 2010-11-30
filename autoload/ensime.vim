" exec scriptmanager#DefineAndBind('s:c','g:ensime','{}')
if !exists('g:ensime') | let g:ensime = {} | endif | let s:c = g:ensime
let s:c['nc'] = get(s:c, 'nc', 'nc 127.0.0.1 PORT')
let s:c['ensime-script'] = get(s:c, 'ensime-script', expand('<sfile>:h:h:h').'/dist/bin/server.sh')
let s:c['ensime-script'] = get(s:c, 'ensime-script', expand('<sfile>:h:h:h').'/dist/bin/server.sh')
let s:c['callId'] = get(s:c, 'callId', 1)

let s:regex_port = 'Server listening on \(\d\+\)\.\.'

" start and connect to ensime server
fun! ensime#StartEnsimeServer()

  " if server is running ask to kill or abort
  if has_key(s:c, 'con')
    if 'k' == input('ensime server is running. type k for killing :')
      " this should also kill the process:
      exec s:c.con.ensime_server_process.bufnr.'bw!'
      call s:c.con.ensime_client_process.kill()
    else
      echo 'user abort'
      return
    endif
  endif

  let s:c.con = {}

  " get temp file name for portfile (which is not used. port is read from
  " stdout)
  if !has_key(s:c, 'portfile')
    let s:c.portfile = tempname()
  endif

  " start server
  let cmd = s:c['ensime-script'].' '.shellescape(s:c.portfile).' '.shellescape('vim')
  let ctx = {'cmd': cmd, 'move_last':1, 'line_prefix': 'server  : '}
  call async_porcelaine#LogToBuffer(ctx)

  " when port is sent to stdout connect using TCP/IP
  fun! ctx.got_port(data)
    let port = matchlist(a:data, s:regex_port)[1]

    " start client process
    echoe "a"
    let ctx = async#Exec({'cmd' : substitute(s:c.nc,'PORT',port,'g')})
    let s:c.con.ensime_client_process = ctx
    let ctx.receive = function('ensime#Receive')
    call async_porcelaine#LineBuffering(ctx)
    " notify user about connection by requesting connection info reply
    EnsimeConnect
  endf
  call ctx.dataTillRegexMatchesLine(s:regex_port, ctx.got_port)

  let s:c.con.ensime_server_process = ctx

  let s:c.con.actions = {}

  " wait for pidfile
endf

fun! s:Log(s)
  let ctx = s:c.con.ensime_server_process
  let lines = [ "VIM LOG : " . a:s]
  call async#DelayUntilNotDisturbing('process-pid'. ctx.pid, {'delay-when': ['buf-invisible:'. ctx.bufnr], 'fun' : function('async#ExecInBuffer'), 'args': [ctx.bufnr, function('append'), ['$', lines]] } )
endf

" send a request to the server
" The result will be received asynchronously by ensime#Receive
" a request object typically look like this:
" ["swank:rpc-proc-name",  .. args .. ]
fun! ensime#Request(request) abort
  let ctx = s:c.con.ensime_client_process
  if has_key(ctx, 'status')
    throw "can't send request to ensime because the client process died"
  endif

  " unique callId:
  let request = [s:c.callId] + a:request
  let s:c.callId += 1

  let s = json_encoding#Encode(request)
  call s:Log('sent: '.s)
  call ctx.write(s."\n")
  return s:c.callId-1
endf

fun! ensime#Receive(...) dict
  " debug by prefixng this line by "debug" and :load % this buffer
  return call(function('ensime#Receive2'), a:000, self)
endf

fun! ensime#Receive2(line, ...) dict
  call s:Log('got: '.a:line)
  let reply = json_encoding#Decode(a:line)
  if has_key(reply, 'error')
    " echoe is not working when called using --remote-expr
    call s:Log(reply.error)
  else
    let data = has_key(reply,'ok') ? reply.ok : reply

    let d = type(data) == type({})

    let callId = get(reply,'callId',-2)

    if get(reply,'callId',-2) == get(get(s:c,'con',{}),'completion_call_id', -1)
      " waiting for completion result
      let s:c.con.completions = data
      call feedkeys(repeat("\<bs>",len(s:wait))."\<c-x>\<c-o>")
    elseif d && has_key(data, 'server-implementation')
      " connection-info reply:
      call s:Log("ensime: connected ".string(data))
    elseif d && has_key(data, 'background-message')
      call s:Log(string(data['background-message']))
    elseif d && has_key(data, 'compiler-ready')
      call s:Log('compiler-ready')
      let s:c.con.compiler_ready = 1
    elseif d && has_key(data, 'source-roots')
      let s:c.con['source-roots'] = data['source-roots']
      let s:c.con['project-name'] = data['project-name']
      call s:Log('source roots are '.string(s:c.con['source-roots']))
    elseif d && has_key(data, 'typecheck-result')
      call ensime#PopulateQuickFix(data['typecheck-result'].notes)
    elseif d && has_key(data, 'notes')
      " result of swank:typecheck-file
      call ensime#PopulateQuickFix(data.notes)
    elseif d && has_key(data, 'classpath')
      call async_porcelaine#ScalaBuffer({'cmd': 'scala -cp '.data.classpath,'move_last':1, 'prompt': 'scala> $'})
    elseif has_key(s:c.con.actions, callId)
      let args = s:c.con.actions[callId]
      call add(args[1], data)
      call call(function('call'), args)
      " unlet s:c.con.actions[callId]
    else
      call s:Log("don't know yet what do to with server result ".string(data))
    endif
  endif
endf

let s:currbuf = ''
fun! s:SortNotes(a, b)
  let currentBuf =  (a:b.file == s:currbuf) - (a:a.file == s:currbuf)
  if currentBuf != 0
    return currentBuf
  else
    return a:a.line - a:b.line
  endif
endf

fun! ensime#PopulateQuickFix(notes)
  let s:currbuf = expand('%:p')
  call sort(a:notes, function('s:SortNotes'))

  let cwd_pat = '^'.substitute(getcwd(),'[/\\]','[/\\\\]','g')

  let list = []
  for n in a:notes
    let l = {'filename' : substitute(n.file, cwd_pat.'.','',''), 'lnum': n.line, 'col': n.col, 'text': n.msg, 'type': n.severity == 'error' ? 'e' : 'w' }
    if get(l,'text','') =~ 'overloaded method constructor .* with alternatives:'
      " split into many lines so that you can read the alternatives more
      " easily

      let r = matchlist(l.text, '\(overloaded method constructor \S\+ with alternatives:\) \(.*\) cannot be applied to \(.*\)')
      let l.text = r[1]
      call add(list, l)
      let alternatives = split(r[2], '\s*<and>\s*')
      let diff = []
      let nr =1
      let found_list = ["found"] + split(r[3],',')
      for alternative in alternatives
        call add(list, {'text': alternative} )
        call add(diff,  "")
        call add(diff,  "alternative ".nr.":")
        let should_list = ["should"] + split(alternative,',')
        for idx in range(0, max([len(should_list), len(found_list)])-1)
          call add(diff, printf("%20s %20s", get(found_list, idx, ""), get(should_list, idx, "")))
        endfor
        let nr += 1
      endfor
      call add(list, {'text': 'cannot be applied to'})
      call add(list, {'text': r[3] })
      call add(list, {'text': "diff parameters for all alternatives" })
      for line_ in diff
        call add(list, {'text': line_})
      endfor
    elseif get(l,'text','') =~ 'type mismatch;\s*found'
      let r = matchlist(l.text, '\(type mismatch;\s*found\)\s*: \(.*\)  required: \(.*\)')
      let l.text = r[1]
      call add(list, l)
      call add(list, {'text': 'found    :'.r[2]})
      call add(list, {'text': 'required :'.r[3]})
    elseif get(l,'text','') =~ 'overloaded method value.*with alternatives'
      let r = matchlist(l.text, '\(overloaded method value\s*\S\+\s*with\s*alternatives\):\s* \(.*\)\s* cannot be applied to \(.*\)')
      let l.text = r[1]
      call add(list, l)
      for alternative in split(r[2], '\s*<and>\s*')
        call add(list, {'text': alternative} )
      endfor
      call add(list, {'text': 'required :'.r[3]})
    else
      call add(list, l)
    endif
  endfor
  call setqflist(list)
  if exists(':UpdateQuickfixSigns') | UpdateQuickfixSigns | endif
endf

" returns config as passed to swank:init-project
fun! ensime#ConfigArg()
  if !has_key(s:c, 'ensime_config')
    if filereadable('.ensime')
      let s:c.ensime_config = ['sexp-string', join(filter(readfile('.ensime'), 'v:val !~ "^\\s*;;"')," ") ,getcwd()]
    else
      throw "no .ensime file found!"
    endif
  endif
  return s:c.ensime_config
endf

fun! ensime#Connect()
  call ensime#Request(['swank:init-project'] + ensime#ConfigArg())
endf

fun! ensime#TypecheckFile()
  let f = expand('%:p')
  if exists('s:c.con["source-roots"]')
    for r in s:c.con['source-roots']
      if f =~ '^'.expand(r)
        " is in source roots. so background typecheck file
        call ensime#Request(['swank:typecheck-file', f])
        return
      endif
    endfor
  endif
endf

" completion {{{1
let s:wait  = "please wait"

" before cursor after cursor
function! ensime#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

fun! ensime#LocationOfCursor()
    let [bc, ac] = ensime#BcAc()
    " code taken from vim-haxe
    let col = getpos('.')[2]
    let linesTillC = getline(1, line('.')-1)+[getline('.')[:(col-1)]]
    let b:realBytePos = len(join(linesTillC,"\n"))
    return [bc, b:realBytePos]
endf

fun! s:SortByWord(a,b)
  return tolower(a:a.word) > tolower(a:b.word)
endf

fun! ensime#Completion(findstart, base)
  if !has_key(s:c.con,'compiler_ready')
    throw "compiler not ready . Did you start Ensime using :Ensime?"
  endif
  if a:findstart
    let [bc, b:realBytePos] = ensime#LocationOfCursor()
    " try to find .
    let s:match_text = matchstr(bc, '\zs[^ \t#().[\]{}\''";: ]*$')
    let b:is_constructor = matchstr(bc, '\zsnew\s\+[^\]{}\''";: ]*$') != ""
    let b:completion_type = bc[len(bc)-len(s:match_text)-1] == '.' ? 'type' : 'scope'
    let s:start = len(bc)-len(s:match_text)
    " pretend not having typed one char at max. This way we can filter stuff in Vim
    " and use camel case matching .. The one char is necessary to keep the
    " returned list of matches small. Else filtering could be too slow
    " foo. the bytepos must be the last o (?)
    let b:bytePos = b:realBytePos - (len(s:match_text) > 0 ? len(s:match_text) - 1 : 0) - (b:completion_type == 'type' ? 2 : 0)
    return s:start
  else
    if exists('s:c.con.completions')
      let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(a:base
            \ , "ocaml_completion", { 'match_beginning_of_string': 1})
      let additional_regex = get(patterns, 'vim_regex', "")

      let r = {}
      for i in s:c.con.completions
        if i.name =~ '^'.a:base || (additional_regex != '' && i.name =~ additional_regex)
          let m = i['type-sig']
          if has_key(r, i.name)
            let r[i.name].menu .= " +"
            let r[i.name].info .= "\n".m
          else
            let r[i.name] = {'word' : i.name.(i['is-callable'] ? '(' : ''), 'menu' : m, 'info': m}
          endif
        endif
      endfor
      unlet s:c.con.completions
      return sort(values(r), function('s:SortByWord'))
    else
      " async reply will retrigger completion
      call feedkeys(s:wait)
      " start completion request
      let prefix = s:match_text[:0]
      let s:c.prevent_typecheck = 1
      update
      let s:c.prevent_typecheck = 0
      let s:c.con.completion_call_id = ensime#Request(["swank:".b:completion_type."-completion", expand('%:p'), b:bytePos, prefix, json_encoding#ToJSONBool(b:is_constructor)])
      return []
    endif
  endif
endf

fun ensime#ReformatSourceAction(files, ...)
  " reload formatted buffers
  for f in a:files
    let b = bufnr(f)
    if b != -1
      exec b.'b | e!'
    endif
  endfor
endf

fun! ensime#FormatSource(sources)
  " make paths absolute
  let files = map(a:sources, 'fnamemodify(v:val, ":p")')
  let s:c.con.actions[ensime#Request(["swank:format-source"] + [files] )] = [function('ensime#ReformatSourceAction'), [files]]
endf

fun! ensime#SymbolAtPointAction(act, data)
  let data = a:data
  if act == 'goto'
    " goto type
    " why does Vim switch syntax off??
    call feedkeys(':e '.fnameescape(data['decl-pos'].file).'|goto '.data['decl-pos'].offset."|syn on\<cr>")
  else
    " show type info in preview window

    " type at request:
    " let s = ['arrow-type: '. data.type['arrow-type'] .' '. data.type.name, string(data['decl-pos'])]
    let s = []
    if exists('data.type["full-name"]')
      call add(s, data.type["full-name"])
    endif
    call add(s, string(data))

    call ensime#Preview(s)
  endif
endfun

" this seems to be a nice way to view data to the user temporarely which does
" not cause segfaults too often:
fun! ensime#Preview(s)
  if !exists('s:ped_file')
    let s:ped_file = tempname()
  endif
  call writefile(a:s, s:ped_file)
  exec 'ped 'fnameescape(s:ped_file)
endf

fun! ensime#TypeAtCursor(act, data)
  let s:c.con.actions[ensime#Request(['swank:symbol-at-point', expand('%:p'), ensime#LocationOfCursor()[1]])] = [function('ensime#SymbolAtPointAction'), [act]]
endf

fun! ensime#FormatInspectionResult(thing, indentation, typehint) abort
  echo string(a:thing)
  if (type(a:thing) == type({})) && has_key(a:thing, "interfaces") && len(keys(a:thing)) ==1
    return "interfaces: \n".join(map(copy(a:thing.interfaces),'ensime#FormatInspectionResult(v:val, a:indentation."  ", "interface")'),"\n")
  elseif a:typehint == "interface"
    " .ensime#FormatInspectionResult(a:thing.type['type-args'],"",'type-args')
    return a:indentation. a:thing.type['full-name'] .' '
      \    ."\n".join(map( copy(a:thing.type.members), 'ensime#FormatInspectionResult(v:val, a:indentation."  ", "member")'),"\n")."\n"

  elseif a:typehint == "typeargs"
    return string(a:thing)
  elseif a:typehint == "member"
    return a:indentation . a:thing.name .' '. a:thing.type.name.'  <'. a:thing.type['result-type']['type-id'].'>'
    " {'name': 'backup', 'decl-as': 'method', 'type': {'arrow-type': 1, 'name': '(x$1: java.lang.String)Unit', 'result-type': {'outer-type-id': 0, 'full-name': 'scala.Unit', 'type-args': [], 'name': 'Unit', 'type-id': 3, 'decl-as': 'class', 'pos': 0, 'members': []}, 'type-id': 2, 'param-sections': [{'is-implicit': 0, 'params': [['x$1', {'outer-type-id': 0, 'full-name': 'java.lang.String', 'type-args': [], 'name': 'String', 'type-id': 1, 'decl-as': 'class', 'pos': 0, 'members': []}]]}]}, 'pos': 0}
  else
    return "uhandled case ".string(a:thing)
  end
endf

fun! ensime#InspectAtCursorAction(data)
  let s = split(ensime#FormatInspectionResult(a:data, "", ""),"\n")
  call ensime#Preview(s)
endf

fun! ensime#InspectTypeById(id)
  let s:c.con.actions[ensime#Request(['swank:inspect-type-by-id', 1*a:id])] = [function('ensime#InspectAtCursorAction'), []]
endf

fun! ensime#InspectAtCursor()
  let s:c.con.actions[ensime#Request(['swank:inspect-type-at-point', expand('%:p'), ensime#LocationOfCursor()[1]])] = [function('ensime#InspectAtCursorAction'), []]
endf
