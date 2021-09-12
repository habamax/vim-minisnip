let s:did_ft = {}


" Reload snippets for all filetypes.
func! minisnip#fs#reloadAllSnippets()
    for ft in keys(s:did_ft)
        call minisnip#fs#reloadSnippets(ft)
    endfor
endfunc


" Reload snippets for filetype.
func! minisnip#fs#reloadSnippets(ft)
    if empty(a:ft) && empty(&ft)
        let ft = '_'
    elseif empty(a:ft)
        let ft = &ft
    else
        let ft = a:ft
    endif
    call s:resetSnippets(ft)
    for snip_dir in split(g:minisnip_dir, ",")
        call s:getSnippets(snip_dir, ft)
    endfor
endfunc


func! s:getSnippets(dir, filetypes)
    for ft in split(a:filetypes, '\.')
        call s:defineSnips(a:dir, ft, ft)
        if ft == 'objc' || ft == 'cpp' || ft == 'cs'
            call s:defineSnips(a:dir, 'c', ft)
        elseif ft == 'xhtml'
            call s:defineSnips(a:dir, 'html', 'xhtml')
        endif
        let s:did_ft[ft] = 1
    endfor
endfunc


" Reset snippets for filetype.
func! s:resetSnippets(ft)
    let ft = a:ft == '' ? '_' : a:ft
    for dict in [g:minisnip_snips, g:minisnip_multi_snips, s:did_ft]
        if has_key(dict, ft)
            unlet dict[ft]
        endif
    endfor
endfunc


" Define "aliasft" snippets for the filetype "realft".
func! s:defineSnips(dir, aliasft, realft)
    for path in split(globpath(a:dir, a:aliasft.'/')."\n".
                    \ globpath(a:dir, a:aliasft.'-*/'), "\n")
        call s:extractSnips(path, a:realft)
    endfor
    for path in split(globpath(a:dir, a:aliasft.'.snippets')."\n".
                    \ globpath(a:dir, a:aliasft.'-*.snippets'), "\n")
        call s:extractSnipsFile(path, a:realft)
    endfor
endfunc


func! s:extractSnips(dir, ft)
    for path in split(globpath(a:dir, '*'), "\n")
        if isdirectory(path)
            let pathname = fnamemodify(path, ':t')
            for snipFile in split(globpath(path, '*.snippet'), "\n")
                call s:processFile(snipFile, a:ft, pathname)
            endfor
        elseif fnamemodify(path, ':e') == 'snippet'
            call s:processFile(path, a:ft)
        endif
    endfor
endfunc


func! s:extractSnipsFile(file, ft)
    if !filereadable(a:file) | return | endif
    let text = readfile(a:file)
    let inSnip = 0
    for line in text + ["\n"]
        if inSnip && (line[0] == "\t" || line == '')
            let content .= strpart(line, 1)."\n"
            continue
        elseif inSnip
            call s:makeSnip(a:ft, trigger, content[:-2], name)
            let inSnip = 0
        endif

        if line[:6] == 'snippet'
            let inSnip = 1
            let trigger = strpart(line, 8)
            let name = ''
            let space = stridx(trigger, ' ') + 1
            if space " Process multi snip
                let name = strpart(trigger, space)
                let trigger = strpart(trigger, 0, space - 1)
            endif
            let content = ''
        endif
    endfor
endfunc


" Processes a single-snippet file; optionally add the name of the parent
" directory for a snippet with multiple matches.
func! s:processFile(file, ft, ...)
    let keyword = fnamemodify(a:file, ':t:r')
    if keyword  == '' | return | endif
    try
        let text = join(readfile(a:file), "\n")
    catch /E484/
        echom "Error in minisnip.vim: couldn't read file: ".a:file
    endtry
    return a:0 ? s:makeSnip(a:ft, a:1, text, keyword)
            \  : s:makeSnip(a:ft, keyword, text)
endfunc


func! s:makeSnip(scope, trigger, content, ...)
    let multisnip = a:0 && a:1 != ''
    let var = multisnip ? 'g:minisnip_multi_snips' : 'g:minisnip_snips'
    if !has_key({var}, a:scope) | let {var}[a:scope] = {} | endif
    if !has_key({var}[a:scope], a:trigger)
        let {var}[a:scope][a:trigger] = multisnip ? [[a:1, a:content]] : a:content
    elseif multisnip
        let {var}[a:scope][a:trigger] += [[a:1, a:content]]
    endif
endfunc
