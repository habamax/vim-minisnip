func! s:cursor(lnum, charcol)
    if has("patch-8.2.2324")
        call setcursorcharpos(a:lnum, a:charcol)
    else
        call cursor(a:lnum, max([byteidx(getline(a:lnum), a:charcol), a:charcol]))
    endif
endfunc

func! minisnip#jumpTabStop(backwards)
    let leftPlaceholder = exists('s:origWordLen')
                          \ && s:origWordLen != g:minisnip_pos[s:curPos][2]
    if leftPlaceholder && exists('s:oldEndCol')
        let startPlaceholder = s:oldEndCol + 1
    endif

    if exists('s:update')
        call s:updatePlaceholderTabStops()
    else
        call s:updateTabStops()
    endif

    " Don't reselect placeholder if it has been modified
    if leftPlaceholder && g:minisnip_pos[s:curPos][2] != -1
        if exists('startPlaceholder')
            let g:minisnip_pos[s:curPos][1] = startPlaceholder
        else
            let g:minisnip_pos[s:curPos][1] = charcol('.')
            let g:minisnip_pos[s:curPos][2] = 0
        endif
    endif

    let s:curPos += a:backwards ? -1 : 1
    " Loop over the snippet when going backwards from the beginning
    if s:curPos < 0 | let s:curPos = s:snipLen - 1 | endif

    if s:curPos == s:snipLen
        let sMode = s:endCol == g:minisnip_pos[s:curPos-1][1]+g:minisnip_pos[s:curPos-1][2]
        call s:removeSnippet()
        return sMode ? "\<tab>" : minisnip#triggerSnippet()
    endif

    call s:cursor(g:minisnip_pos[s:curPos][0], g:minisnip_pos[s:curPos][1])

    let s:endLine = g:minisnip_pos[s:curPos][0]
    let s:endCol = g:minisnip_pos[s:curPos][1]
    let s:prevLen = [line('$'), charcol('$')]

    return g:minisnip_pos[s:curPos][2] == -1 ? '' : s:selectWord()
endfunc

func! minisnip#expandSnip(snip, col)
    let lnum = line('.') | let col = a:col

    let snippet = s:processSnippet(a:snip)
    " Avoid error if eval evaluates to nothing
    if snippet == '' | return '' | endif

    " Expand snippet onto current position with the tab stops removed
    let snipLines = split(substitute(snippet, '$\d\+\|${\d\+.\{-}}', '', 'g'), "\n", 1)

    let line = getline(lnum)
    let afterCursor = strcharpart(line, col - 1)
    " Keep text after the cursor
    if afterCursor != "\t" && afterCursor != ' '
        let line = strcharpart(line, 0, col - 1)
        let snipLines[-1] .= afterCursor
    else
        let afterCursor = ''
        " For some reason the cursor needs to move one right after this
        if line != '' && col == 1 && &ve != 'all' && &ve != 'onemore'
            let col += 1
        endif
    endif

    call setline(lnum, line.snipLines[0])

    " Autoindent snippet according to previous indentation
    let indent = matchend(line, '^.\{-}\ze\(\S\|$\)') + 1
    call append(lnum, map(snipLines[1:], "'".strcharpart(line, 0, indent - 1)."'.v:val"))

    " Open any folds snippet expands into
    if &fen | sil! exe lnum.','.(lnum + len(snipLines) - 1).'foldopen' | endif

    let [g:minisnip_pos, s:snipLen] = s:buildTabStops(snippet, lnum, col - indent, indent)

    if s:snipLen
        augroup minisnipAutocmds | au!
            au CursorMovedI <buffer> call s:updateChangedSnip(0)
            au InsertEnter <buffer> call s:updateChangedSnip(1)
        augroup END
        let s:lastBuf = bufnr(0) " Only expand snippet while in current buffer
        let s:curPos = 0
        let s:endCol = g:minisnip_pos[s:curPos][1]
        let s:endLine = g:minisnip_pos[s:curPos][0]

        call s:cursor(g:minisnip_pos[s:curPos][0], g:minisnip_pos[s:curPos][1])
        let s:prevLen = [line('$'), charcol('$')]
        if g:minisnip_pos[s:curPos][2] != -1 | return s:selectWord() | endif
    else
        unl g:minisnip_pos s:snipLen
        " Place cursor at end of snippet if no tab stop is given
        let newlines = len(snipLines) - 1
        call s:cursor(lnum + newlines, indent + strchars(snipLines[-1]) - strchars(afterCursor)
                    \ + (newlines ? 0: col - 1))
    endif
    return ''
endfunc

fun! minisnip#triggerSnippet()
    if pumvisible()
        call feedkeys("\<esc>a", 'n') " Close completion menu
        call feedkeys("\<tab>") | return ''
    endif

    if exists('g:minisnip_pos') | return minisnip#jumpTabStop(0) | endif

    " Here col() instead of charcol() should be used
    " otherwise matchstr returns wrong expand word to trigger with
    " if there is multibyte chars before the cursor
    " Note: Recent vim has \%.c that matches at cursor position.
    let word = matchstr(getline('.'), '\S\+\%'.col('.').'c')
    for scope in [bufnr('%')] + split(&ft, '\.') + ['_']
        let [trigger, snippet] = s:getSnippet(word, scope)
        " If word is a trigger for a snippet, delete the trigger & expand
        " the snippet.
        if snippet != ''
            let col = charcol('.') - strchars(trigger)
            sil exe 's/\V'.escape(trigger, '/\.').'\%#//'
            return minisnip#expandSnip(snippet, col)
        endif
    endfor

    return "\<tab>"
endfunc

fun! minisnip#backwardsSnippet()
    if exists('g:minisnip_pos') | return minisnip#jumpTabStop(1) | endif
    return "\<s-tab>"
endfunc

fun! minisnip#showAvailableSnippets()
    let line  = getline('.')
    let col   = charcol('.')
    let word  = matchstr(getline('.'), '\S\+\%'.col.'c')
    let words = [word]
    if stridx(word, '.')
        let words += split(word, '\.', 1)
    endif
    let matchlen = 0
    let matches = []
    for scope in [bufnr('%')] + split(&ft, '\.') + ['_']
        let triggers = has_key(g:minisnip_snips, scope) ? keys(g:minisnip_snips[scope]) : []
        if has_key(g:minisnip_multi_snips, scope)
            let triggers += keys(g:minisnip_multi_snips[scope])
        endif
        for trigger in triggers
            for word in words
                if word == ''
                    let matches += [trigger] " Show all matches if word is empty
                elseif trigger =~ '^'.word
                    let matches += [trigger]
                    let len = strchars(word)
                    if len > matchlen | let matchlen = len | endif
                endif
            endfor
        endfor
    endfor

    " This is to avoid a bug with Vim when using complete(col - matchlen, matches)
    " (Issue#46 on the Google Code minisnip issue tracker).
    call setline(line('.'), substitute(line, repeat('.', matchlen).'\%'.col.'c', '', ''))
    call complete(col, matches)
    return ''
endfunc



" Check if word under cursor is snippet trigger; if it isn't, try checking if
" the text after non-word characters is (e.g. check for "foo" in "bar.foo")
func! s:getSnippet(word, scope)
    let word = a:word | let snippet = ''
    while snippet == ''
        if exists('g:minisnip_snips["'.a:scope.'"]["'.escape(word, '\"').'"]')
            let snippet = g:minisnip_snips[a:scope][word]
        elseif exists('g:minisnip_multi_snips["'.a:scope.'"]["'.escape(word, '\"').'"]')
            let snippet = s:chooseSnippet(a:scope, word)
            if snippet == '' | break | endif
        else
            if match(word, '\W') == -1 | break | endif
            let word = substitute(word, '.\{-}\W', '', '')
        endif
    endw
    if word == '' && a:word != '.' && stridx(a:word, '.') != -1
        let [word, snippet] = s:getSnippet('.', a:scope)
    endif
    return [word, snippet]
endfunc

func! s:chooseSnippet(scope, trigger)
    let snippet = []
    let i = 1
    for snip in g:minisnip_multi_snips[a:scope][a:trigger]
        let snippet += [i.'. '.snip[0]]
        let i += 1
    endfor
    if i == 2 | return g:minisnip_multi_snips[a:scope][a:trigger][0][1] | endif
    let num = inputlist(snippet) - 1
    return num == -1 ? '' : g:minisnip_multi_snips[a:scope][a:trigger][num][1]
endfunc

" Cleanup snippet vars
func! s:removeSnippet()
    unl! g:minisnip_pos s:curPos s:snipLen s:endCol s:endLine s:prevLen
         \ s:lastBuf s:oldWord
    if exists('s:update')
        unl s:startCol s:origWordLen s:update
        if exists('s:oldVars') | unl s:oldVars s:oldEndCol | endif
    endif
endfunc

" Prepare snippet to be processed by s:buildTabStops
func! s:processSnippet(snip)
    let snippet = a:snip
    " Evaluate eval (`...`) expressions.
    " Backquotes prefixed with a backslash "\" are ignored.
    " Using a loop here instead of a regex fixes a bug with nested "\=".
    if stridx(snippet, '`') != -1
        while match(snippet, '\(^\|[^\\]\)`.\{-}[^\\]`') != -1
            let snippet = substitute(snippet, '\(^\|[^\\]\)\zs`.\{-}[^\\]`\ze',
                        \ substitute(eval(matchstr(snippet, '\(^\|[^\\]\)`\zs.\{-}[^\\]\ze`')),
                        \ "\n\\%$", '', ''), '')
        endw
        let snippet = substitute(snippet, "\r", "\n", 'g')
        let snippet = substitute(snippet, '\\`', '`', 'g')
    endif

    " Place all text after a colon in a tab stop after the tab stop
    " (e.g. "${#:foo}" becomes "${:foo}foo").
    " This helps tell the position of the tab stops later.
    let snippet = substitute(snippet, '${\d\+:\(.\{-}\)}', '&\1', 'g')

    " Update the a:snip so that all the $# become the text after
    " the colon in their associated ${#}.
    " (e.g. "${1:foo}" turns all "$1"'s into "foo")
    let i = 1
    while stridx(snippet, '${'.i) != -1
        let s = matchstr(snippet, '${'.i.':\zs.\{-}\ze}')
        if s != ''
            let snippet = substitute(snippet, '$'.i, s.'&', 'g')
        endif
        let i += 1
    endw

    if &et " Expand tabs to spaces if 'expandtab' is set.
        return substitute(snippet, "\t", repeat(' ', &sts > 0 ? &sts : &sw), 'g')
    endif
    return snippet
endfunc

" Counts occurences of haystack in needle
func! s:count(haystack, needle)
    let counter = 0
    let index = stridx(a:haystack, a:needle)
    while index != -1
        let index = stridx(a:haystack, a:needle, index+1)
        let counter += 1
    endw
    return counter
endfunc

" Builds a list of a list of each tab stop in the snippet containing:
" 1.) The tab stop's line number.
" 2.) The tab stop's column number
"     (by getting the length of the string between the last "\n" and the
"     tab stop).
" 3.) The length of the text after the colon for the current tab stop
"     (e.g. "${1:foo}" would return 3). If there is no text, -1 is returned.
" 4.) If the "${#:}" construct is given, another list containing all
"     the matches of "$#", to be replaced with the placeholder. This list is
"     composed the same way as the parent; the first item is the line number,
"     and the second is the column.
func! s:buildTabStops(snip, lnum, col, indent)
    let snipPos = []
    let i = 1
    let withoutVars = substitute(a:snip, '$\d\+', '', 'g')
    while stridx(a:snip, '${'.i) != -1
        let beforeTabStop = matchstr(withoutVars, '^.*\ze${'.i.'\D')
        let withoutOthers = substitute(withoutVars, '${\('.i.'\D\)\@!\d\+.\{-}}', '', 'g')

        let j = i - 1
        call add(snipPos, [0, 0, -1])
        let snipPos[j][0] = a:lnum + s:count(beforeTabStop, "\n")
        let snipPos[j][1] = a:indent + strchars(matchstr(withoutOthers, '.*\(\n\|^\)\zs.*\ze${'.i.'\D'))
        if snipPos[j][0] == a:lnum | let snipPos[j][1] += a:col | endif

        " Get all $# matches in another list, if ${#:name} is given
        if stridx(withoutVars, '${'.i.':') != -1
            let snipPos[j][2] = strchars(matchstr(withoutVars, '${'.i.':\zs.\{-}\ze}'))
            let dots = repeat('.', snipPos[j][2])
            call add(snipPos[j], [])
            let withoutOthers = substitute(a:snip, '${\d\+.\{-}}\|$'.i.'\@!\d\+', '', 'g')
            while match(withoutOthers, '$'.i.'\(\D\|$\)') != -1
                let beforeMark = matchstr(withoutOthers, '^.\{-}\ze'.dots.'$'.i.'\(\D\|$\)')
                call add(snipPos[j][3], [0, 0])
                let snipPos[j][3][-1][0] = a:lnum + s:count(beforeMark, "\n")
                let snipPos[j][3][-1][1] = a:indent + (snipPos[j][3][-1][0] > a:lnum
                                           \ ? strchars(matchstr(beforeMark, '.*\n\zs.*'))
                                           \ : a:col + strchars(beforeMark))
                let withoutOthers = substitute(withoutOthers, '$'.i.'\ze\(\D\|$\)', '', '')
            endw
        endif
        let i += 1
    endw
    return [snipPos, i - 1]
endfunc

func! s:updatePlaceholderTabStops()
    let changeLen = s:origWordLen - g:minisnip_pos[s:curPos][2]
    unl s:startCol s:origWordLen s:update
    if !exists('s:oldVars') | return | endif
    " Update tab stops in snippet if text has been added via "$#"
    " (e.g., in "${1:foo}bar$1${2}").
    if changeLen != 0
        let curLine = line('.')

        for pos in g:minisnip_pos
            if pos == g:minisnip_pos[s:curPos] | continue | endif
            let changed = pos[0] == curLine && pos[1] > s:oldEndCol
            let changedVars = 0
            let endPlaceholder = pos[2] - 1 + pos[1]
            " Subtract changeLen from each tab stop that was after any of
            " the current tab stop's placeholders.
            for [lnum, col] in s:oldVars
                if lnum > pos[0] | break | endif
                if pos[0] == lnum
                    if pos[1] > col || (pos[2] == -1 && pos[1] == col)
                        let changed += 1
                    elseif col < endPlaceholder
                        let changedVars += 1
                    endif
                endif
            endfor
            let pos[1] -= changeLen * changed
            let pos[2] -= changeLen * changedVars " Parse variables within placeholders
                                                  " e.g., "${1:foo} ${2:$1bar}"

            if pos[2] == -1 | continue | endif
            " Do the same to any placeholders in the other tab stops.
            for nPos in pos[3]
                let changed = nPos[0] == curLine && nPos[1] > s:oldEndCol
                for [lnum, col] in s:oldVars
                    if lnum > nPos[0] | break | endif
                    if nPos[0] == lnum && nPos[1] > col
                        let changed += 1
                    endif
                endfor
                let nPos[1] -= changeLen * changed
            endfor
        endfor
    endif
    unl s:endCol s:oldVars s:oldEndCol
endfunc

func! s:updateTabStops()
    let changeLine = s:endLine - g:minisnip_pos[s:curPos][0]
    let changeCol = s:endCol - g:minisnip_pos[s:curPos][1]
    if exists('s:origWordLen')
        let changeCol -= s:origWordLen
        unl s:origWordLen
    endif
    let lnum = g:minisnip_pos[s:curPos][0]
    let col = g:minisnip_pos[s:curPos][1]
    " Update the line number of all proceeding tab stops if <cr> has
    " been inserted.
    if changeLine != 0
        let changeLine -= 1
        for pos in g:minisnip_pos
            if pos[0] >= lnum
                if pos[0] == lnum | let pos[1] += changeCol | endif
                let pos[0] += changeLine
            endif
            if pos[2] == -1 | continue | endif
            for nPos in pos[3]
                if nPos[0] >= lnum
                    if nPos[0] == lnum | let nPos[1] += changeCol | endif
                    let nPos[0] += changeLine
                endif
            endfor
        endfor
    elseif changeCol != 0
        " Update the column of all proceeding tab stops if text has
        " been inserted/deleted in the current line.
        for pos in g:minisnip_pos
            if pos[1] >= col && pos[0] == lnum
                let pos[1] += changeCol
            endif
            if pos[2] == -1 | continue | endif
            for nPos in pos[3]
                if nPos[0] > lnum | break | endif
                if nPos[0] == lnum && nPos[1] >= col
                    let nPos[1] += changeCol
                endif
            endfor
        endfor
    endif
endfunc

func! s:selectWord()
    let s:origWordLen = g:minisnip_pos[s:curPos][2]
    let s:oldWord = strcharpart(getline('.'), g:minisnip_pos[s:curPos][1] - 1,
                \ s:origWordLen)
    let s:prevLen[1] -= s:origWordLen
    if !empty(g:minisnip_pos[s:curPos][3])
        let s:update = 1
        let s:endCol = -1
        let s:startCol = g:minisnip_pos[s:curPos][1] - 1
    endif
    if !s:origWordLen | return '' | endif
    let l = charcol('.') != 1 ? 'l' : ''
    if &sel == 'exclusive'
        return "\<esc>".l.'v'.s:origWordLen."l\<c-g>"
    endif
    return s:origWordLen == 1 ? "\<esc>".l.'gh'
                            \ : "\<esc>".l.'v'.(s:origWordLen - 1)."l\<c-g>"
endfunc

" This updates the snippet as you type when text needs to be inserted
" into multiple places (e.g. in "${1:default text}foo$1bar$1",
" "default text" would be highlighted, and if the user types something,
" updateChangedSnip() would be called so that the text after "foo" & "bar"
" are updated accordingly)
"
" It also automatically quits the snippet if the cursor is moved out of it
" while in insert mode.
func! s:updateChangedSnip(entering)
    if exists('g:minisnip_pos') && bufnr(0) != s:lastBuf
        call s:removeSnippet()
    elseif exists('s:update') " If modifying a placeholder
        if !exists('s:oldVars') && s:curPos + 1 < s:snipLen
            " Save the old snippet & word length before it's updated
            " s:startCol must be saved too, in case text is added
            " before the snippet (e.g. in "foo$1${2}bar${1:foo}").
            let s:oldEndCol = s:startCol
            let s:oldVars = deepcopy(g:minisnip_pos[s:curPos][3])
        endif
        let col = charcol('.') - 1

        if s:endCol != -1
            let changeLen = charcol('$') - s:prevLen[1]
            let s:endCol += changeLen
        else " When being updated the first time, after leaving select mode
            if a:entering | return | endif
            let s:endCol = col - 1
        endif

        " If the cursor moves outside the snippet, quit it
        if line('.') != g:minisnip_pos[s:curPos][0] || col < s:startCol ||
                    \ col - 1 > s:endCol
            unl! s:startCol s:origWordLen s:oldVars s:update
            return s:removeSnippet()
        endif

        call s:updateVars()
        let s:prevLen[1] = charcol('$')
    elseif exists('g:minisnip_pos')
        if !a:entering && g:minisnip_pos[s:curPos][2] != -1
            let g:minisnip_pos[s:curPos][2] = -2
        endif

        let col = charcol('.')
        let lnum = line('.')
        let changeLine = line('$') - s:prevLen[0]

        if lnum == s:endLine
            let s:endCol += charcol('$') - s:prevLen[1]
            let s:prevLen = [line('$'), charcol('$')]
        endif
        if changeLine != 0
            let s:endLine += changeLine
            let s:endCol = col
        endif

        " Delete snippet if cursor moves out of it in insert mode
        if (lnum == s:endLine && (col > s:endCol || col < g:minisnip_pos[s:curPos][1]))
            \ || lnum > s:endLine || lnum < g:minisnip_pos[s:curPos][0]
            call s:removeSnippet()
        endif
    endif
endfunc

" This updates the variables in a snippet when a placeholder has been edited.
" (e.g., each "$1" in "${1:foo} $1bar $1bar")
func! s:updateVars()
    let newWordLen = s:endCol - s:startCol + 1
    let newWord = strcharpart(getline('.'), s:startCol, newWordLen)
    if newWord == s:oldWord || empty(g:minisnip_pos[s:curPos][3])
        return
    endif

    let changeLen = g:minisnip_pos[s:curPos][2] - newWordLen
    let curLine = line('.')
    let startCol = charcol('.')
    let oldStartSnip = s:startCol
    let updateTabStops = changeLen != 0
    let i = 0

    for [lnum, col] in g:minisnip_pos[s:curPos][3]
        if updateTabStops
            let start = s:startCol
            if lnum == curLine && col <= start
                let s:startCol -= changeLen
                let s:endCol -= changeLen
            endif
            for nPos in g:minisnip_pos[s:curPos][3][(i):]
                " This list is in ascending order, so quit if we've gone too far.
                if nPos[0] > lnum | break | endif
                if nPos[0] == lnum && nPos[1] > col
                    let nPos[1] -= changeLen
                endif
            endfor
            if lnum == curLine && col > start
                let col -= changeLen
                let g:minisnip_pos[s:curPos][3][i][1] = col
            endif
            let i += 1
        endif

        " "Very nomagic" is used here to allow special characters.
        call setline(lnum, substitute(getline(lnum), '\%'.col.'c\V'.
                        \ escape(s:oldWord, '\'), escape(newWord, '\&'), ''))
    endfor
    if oldStartSnip != s:startCol
        call s:cursor(0, startCol + s:startCol - oldStartSnip)
    endif

    let s:oldWord = newWord
    let g:minisnip_pos[s:curPos][2] = newWordLen
endfunc
