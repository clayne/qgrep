" User dictionary
let g:Qgrep = {
    \ 'qgrep': 'libcall:'.expand('<sfile>:h:h').'/qgrep',
    \ 'project': '*',
    \ 'searchtype': 'ft',
    \ 'limit': 128,
    \ 'keymap': {
        \ 'qgrep#selectProject()':  ['<C-q>'],
    \ },
    \ }

" Global options
let s:globalopts = {
    \ 'guicursor': 'a:blinkon0',
    \ 'hlsearch': 0,
    \ 'imdisable': 1,
    \ 'mouse': 'n',
    \ 'mousef': 0,
    \ 'showcmd': 0,
    \ 'timeout': 1,
    \ 'timeoutlen': 0,
    \ }

" Key mappings
let s:keymap = {
    \ 's:onDeleteChar(%s, -1)': ['<BS>', '<C-]>'],
    \ 's:onDeleteChar(%s, 0)':  ['<Del>'],
    \ 's:onMoveLine(%s, "j")':  ['<C-j>', '<Down>'],
    \ 's:onMoveLine(%s, "k")':  ['<C-k>', '<Up>'],
    \ 's:onMoveLine(%s, "gg")': ['<Home>', '<kHome>'],
    \ 's:onMoveLine(%s, "G")':  ['<End>', '<kEnd>'],
    \ 's:onMoveLine(%s, "pk")': ['<PageUp>', '<kPageUp>'],
    \ 's:onMoveLine(%s, "pj")': ['<PageDown>', '<kPageDown>'],
    \ 's:onMoveCursor(%s, -1)': ['<C-h>', '<Left>', '<C-^>'],
    \ 's:onMoveCursor(%s, +1)': ['<C-l>', '<Right>'],
    \ 'qgrep#close()':          ['<Esc>', '<C-c>'],
    \ }

function! s:state()
    return s:state
endfunction

function! s:echoHighlight(group, text)
    execute 'echohl' a:group
    echon a:text
    echohl None
endfunction

function! s:splitPattern(pattern)
    let pos = stridx(a:pattern, ':')
    if pos < 0
        return [a:pattern, '']
    else
        return [strpart(a:pattern, 0, pos), strpart(a:pattern, pos)]
    endif
endfunction

function! s:renderPrompt(state)
    let state = a:state
    let text = state.pattern
    let cursor = state.cursor

    redraw
    call s:echoHighlight('Comment', '>>> ')
    call s:echoHighlight('Normal', strpart(text, 0, cursor))
    call s:echoHighlight('Constant', strpart(text, cursor, 1))
    call s:echoHighlight('Normal', strpart(text, cursor + 1))

    if cursor >= len(text)
        call s:echoHighlight('Constant', '_')
    endif
endfunction

function! s:formatLine(str)
    return '  '.a:str
endfunction

function! s:renderResults(lines)
    let height = min([len(a:lines), 5])
    setlocal modifiable
    silent! execute '%d'
    silent! execute 'resize' height
    call setline(1, map(copy(a:lines), 's:formatLine(v:val)'))
    setlocal nomodifiable
endfunction

function! s:renderStatus(state, matches, uptime, retime)
    let res = []

    call add(res, "qgrep")
    call add(res, g:Qgrep.project)

    if a:matches < a:state.limit
        call add(res, printf("%d matches", a:matches))
    else
        call add(res, printf("%d+ matches", a:matches))
    endif

    call add(res, printf("update %.f ms", a:uptime))
    call add(res, printf("render %.f ms", a:retime))

    let groups = ["LineNr", "None"]

    let &l:statusline = join(map(copy(res), '"%#" . groups[v:key % 2] . "# " . v:val . " %*"'), '')
endfunction

function! s:hixform(text, pattern)
    let ltext = tolower(a:text)
    let lpattern = tolower(a:pattern)
    let i = 0
    let last = -1
    let res = ''
    while i < len(a:pattern)
        let pos = stridx(ltext, strpart(lpattern, i, 1), last == -1 ? last : last + 1)
        let res .= strpart(a:text, last + 1, pos - last - 1)
        let res .= "\x16"
        let res .= strpart(a:text, pos, 1)
        let i += 1
        let last = pos
    endwhile
    let res .= strpart(a:text, last + 1)
    return res
endfunction

function! s:diffms(start, end)
    return str2float(reltimestr(reltime(a:start, a:end))) * 1000
endfunction

function! s:updateResults(state)
    let state = a:state
    let [pattern, cmd] = s:splitPattern(state.pattern)
    let start = reltime()
    let results = qgrep#execute(['files', g:Qgrep.project, g:Qgrep.searchtype, 'L'.state.limit, pattern])
    let mid = reltime()
    call map(results, 's:hixform(v:val, pattern)')
    call s:renderResults(results)
    call cursor(state.line, 1)
    let end = reltime()
    call s:renderStatus(state, len(results), s:diffms(start, mid), s:diffms(mid, end))
endfunction

function! s:onPatternChanged(state)
    call s:updateResults(a:state)
    call s:renderPrompt(a:state)
endfunction

function! s:onPromptChanged(state)
    call s:renderPrompt(a:state)
endfunction

function! s:onInsertChar(state, char)
    let state = a:state
    let state.pattern = strpart(state.pattern, 0, state.cursor) . a:char . strpart(state.pattern, state.cursor)
    let state.cursor += 1
    call s:onPatternChanged(state)
endfunction

function! s:onDeleteChar(state, offset)
    let state = a:state
    let state.pattern = strpart(state.pattern, 0, state.cursor + a:offset) . strpart(state.pattern, state.cursor + a:offset + 1)
    if state.cursor > 0 && a:offset < 0
        let state.cursor -= 1
    endif
    call s:onPatternChanged(state)
endfunction

function! s:onMoveCursor(state, diff)
    let state = a:state
    let state.cursor += a:diff
    let state.cursor = max([0, min([state.cursor, len(state.pattern)])])
    call s:onPromptChanged(state)
endfunction

function! s:onMoveLine(state, type)
    let state = a:state
    let motion = (a:type[0] == 'p') ? winheight(0) . a:type[1:] : a:type
    execute 'keepjumps' 'normal!' motion
    let state.line = line('.')
    call s:onPromptChanged(state)
endfunction

function! s:initSyntax()
    syntax clear
    syntax match Identifier /\%x16\@<=./
    syntax match Ignore /\%x16/ conceal
endfunction

function! s:initOptions(state)
    " Global options
    let a:state.globalopts = {}

    for [k, v] in items(s:globalopts)
        if exists('+'.k)
            let a:state.globalopts[k] = eval('&'.k)
            execute 'let &'.k.'='.string(v)
        endif
    endfor

    " Local options
    setlocal bufhidden=unload
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal colorcolumn=0
    setlocal concealcursor=n
    setlocal conceallevel=2
    setlocal nocursorcolumn
    setlocal cursorline
    setlocal foldcolumn=0
    setlocal nofoldenable
    setlocal nolist
    setlocal nomodifiable
    setlocal number
    setlocal numberwidth=4
    setlocal norelativenumber
    setlocal nospell
    setlocal noswapfile
    setlocal winfixheight
    setlocal nowrap
endfunction

function! s:initKeys(stateexpr)
	" normal keys
    let charcmd = 'nnoremap <buffer> <silent> <char-%d> :call <SID>onInsertChar(%s, "%s")<CR>'
	for ch in range(32, 126)
		execute printf(charcmd, ch, a:stateexpr, escape(nr2char(ch), '"|\'))
	endfor

    " special keys
    let keymap = extend(copy(s:keymap), g:Qgrep.keymap)

    for [expr, keys] in items(keymap)
        let expr = stridx(expr, '%s') < 0 ? expr : printf(expr, a:stateexpr)
        let expr = expr[0:1] == 's:' ? '<SID>'.expr[2:] : expr
        for key in keys
            execute 'nnoremap <buffer> <silent>' key ':call' expr '<CR>'
        endfor
    endfor
endfunction

function! s:open()
    let state = {}
    let state.cursor = 0
    let state.pattern = ''
    let state.line = 0
    let state.limit = g:Qgrep.limit

    let s:state = state

	silent! keepalt botright 1new Qgrep
    abclear <buffer>

    call s:initOptions(state)
    call s:initSyntax()
    call s:initKeys('<SID>state()')

    call s:updateResults(state)
    call s:renderPrompt(state)
endfunction

function! s:close()
    if exists('s:state')
        for [k, v] in items(s:state.globalopts)
            silent! execute 'let &'.k.'='.string(v)
        endfor

        bunload!
        echo
        unlet! s:state
    endif
endfunction

function! qgrep#open()
    noautocmd call s:open()
endfunction

function! qgrep#close()
    noautocmd call s:close()
endfunction

function! qgrep#update()
    if exists('s:state')
        call s:onPatternChanged(s:state)
    endif
endfunction

function! qgrep#execute(args)
    let path = g:Qgrep.qgrep

    try
        if path[0:7] == 'libcall:'
            let args = join(a:args, "\n")
            let results = libcall(path[8:], 'entryPointVim', args)
        else
            let args = map(copy(a:args), 'shellescape(v:val)')
            let results = system(path . ' ' . join(args, ' '))
        endif

        return split(results, "\n")
    catch
        return []
    endtry
endfunction

function! qgrep#selectProject()
    let projects = qgrep#execute(['projects'])

    let lines = copy(projects)
    call map(lines, 'printf("%2d. %s", v:key + 1, v:val)')
    call insert(lines, 'Select project (*):')

    let choice = inputlist(lines)
    if choice >= 0 && choice <= len(projects)
        let project = (choice == 0) ? '*' : projects[choice - 1]
        let g:Qgrep.project = project

        call qgrep#update()
    endif
endfunction

if has('autocmd')
	augroup QgrepAug
		autocmd!
		autocmd BufLeave Qgrep call qgrep#close()
	augroup END
endif