if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let undo_opts = "setl noet< sw< cms<"

setlocal noexpandtab
setlocal shiftwidth=0
setlocal commentstring=#\ %s

if exists('b:undo_ftplugin')
    let b:undo_ftplugin .= "|" .. undo_opts
else
    let b:undo_ftplugin = undo_opts
endif
