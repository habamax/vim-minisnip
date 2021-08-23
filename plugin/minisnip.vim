if exists('loaded_minisnip') || &cp || version < 700
    finish
endif
let loaded_minisnip = 1

if !exists('snippets_dir')
    let snippets_dir = substitute(globpath(&rtp, 'snippets/'), "\n", ',', 'g')
endif

let g:minisnip_snips = {}
let g:minisnip_multi_snips = {}

inoremap <silent> <tab> <c-r>=minisnip#triggerSnippet()<cr>
snoremap <silent> <tab> <esc>i<right><c-r>=minisnip#triggerSnippet()<cr>
inoremap <silent> <s-tab> <c-r>=minisnip#backwardsSnippet()<cr>
snoremap <silent> <s-tab> <esc>i<right><c-r>=minisnip#backwardsSnippet()<cr>
inoremap <silent> <c-r><tab> <c-r>=minisnip#showAvailableSnips()<cr>

call minisnip#fs#reloadSnippets('_') " Get global snippets
au FileType * if &ft != 'help' | call minisnip#fs#reloadSnippets(&ft) | endif
