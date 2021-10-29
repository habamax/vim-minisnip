" Vim minisnip snippet indent file
" Language: minisnip
" Maintainer: Maxim Kim <habamax@gmail.com>

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

let s:undo_opts = "setl inde< si<"

if exists('b:undo_indent')
    let b:undo_indent .= "|" . s:undo_opts
else
    let b:undo_indent = s:undo_opts
endif

setlocal indentexpr=MinisnipIndent()
setlocal nosmartindent

if exists("*MinisnipIndent")
    finish
endif

func! MinisnipIndent() abort
    let line = getline(v:lnum)
    let ppline = getline(prevnonblank(v:lnum - 1))

    " prev non blank is a .. directive
    " add single indent
    if ppline =~ '^snippet\s' && line !~ '^\t\s*'
        return shiftwidth()
    endif

    if line !~ '^\%(\t\|snippet\>\)'
        return shiftwidth()
    endif

    return -1
endfunc

