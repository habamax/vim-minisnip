if exists("b:current_syntax")
    finish
endif

syn match minisnipComment '^#.*'
syn match minisnipPlaceHolder '\${\d\+\(:.\{-}\)\=}' contains=minisnipCommand
syn match minisnipTabStop '\$\d\+'
syn region minisnipCommand start='[^\\]\zs`[^`[:space:]]' skip='\\`' end='[^[:space:]]`\@<!`' oneline
syn match minisnippet '^snippet.*' transparent contains=minisnipMultiText,minisnipKeyword
syn match minisnipMultiText '\S\+ \zs.*' contained
syn match minisnipKeyword '^snippet'me=s+8 contained
syn match minisnipError "^[^#s\t].*$"

hi def link minisnipComment     Comment
hi def link minisnipMultiText   String
hi def link minisnipKeyword     Keyword
hi def link minisnipComment     Comment
hi def link minisnipPlaceHolder Special
hi def link minisnipTabStop     Special
hi def link minisnipCommand     String
hi def link minisnipError       Error

let b:current_syntax = "minisnip"
