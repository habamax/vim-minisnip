if exists('g:loaded_minisnip') || &cp || version < 802
    finish
endif
let g:loaded_minisnip = 1

if !exists('g:minisnip_dir')
    let g:minisnip_dir = substitute(globpath(&rtp, 'snippets/'), "\n", ',', 'g')
endif

let g:minisnip_snips = {}
let g:minisnip_multi_snips = {}

command MinisnipReloadAll :call minisnip#fs#reloadAllSnippets()
command -nargs=? -complete=filetype MinisnipReload :call minisnip#fs#reloadSnippets(<q-args>)

inoremap <silent> <Plug>(minisnipTrigger) <c-r>=minisnip#triggerSnippet()<cr>
snoremap <silent> <Plug>(minisnipTrigger) <esc>i<right><c-r>=minisnip#triggerSnippet()<cr>
inoremap <silent> <Plug>(minisnipBackwards) <c-r>=minisnip#backwardsSnippet()<cr>
snoremap <silent> <Plug>(minisnipBackwards) <esc>i<right><c-r>=minisnip#backwardsSnippet()<cr>
inoremap <silent> <Plug>(minisnipShowAvailable) <c-r>=minisnip#showAvailableSnippets()<cr>

if get(g:, "minisnip_default_maps", v:false)
    imap <tab> <Plug>(minisnipTrigger)
    smap <tab> <Plug>(minisnipTrigger)
    imap <s-tab> <Plug>(minisnipBackwards)
    smap <s-tab> <Plug>(minisnipBackwards)
    imap <c-r><tab> <Plug>(minisnipShowAvailable)
endif

MinisnipReload _
au FileType * MinisnipReload
