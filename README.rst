********************************************************************************
                vim-minisnip: snipmate.vim based snippets plugin
********************************************************************************

Snippets plugin based on `snipmate.vim`_.

.. _snipmate.vim: https://github.com/msanders/snipmate.vim


Installation
============

Use plugin manager of your choice or

.. code:: sh

  git clone --depth=1 https://github.com/habamax/vim-minisnip.git ~/.vim/pack/plug/start/vim-minisnip


Default mappings
================

To use default mappings:

.. code:: vim

  let g:minisnip_default_maps = 1

This would map :kbd:`<tab>`, :kbd:`<s-tab>` and :kbd:`<C-r><tab>` in insert and select modes.

To map your own keys use :kbd:`<Plug>` mappings:

.. code:: vim

  let g:minisnip_default_maps = 0
  imap <C-j> <Plug>(minisnipTrigger)
  smap <C-j> <Plug>(minisnipTrigger)
  imap <C-k> <Plug>(minisnipBackwards)
  smap <C-k> <Plug>(minisnipBackwards)
  imap <C-r><C-j> <Plug>(minisnipShowAvailable)


Default snippets
================

There are no default snippets, create your own:

.. code:: sh

  mkdir -p ~/.vim/snippets


Example snippets
----------------

Global
~~~~~~
.. code:: sh

  vim ~/.vim/snippets/_.snippet

.. code::

  snippet dd
  	`strftime("%Y-%m-%d")`
  snippet ddt
  	`strftime("%Y-%m-%d %H:%M")`
  snippet me
  	Your Name


Filetype
~~~~~~~~
.. code:: sh

  vim ~/.vim/snippets/tex.snippet


.. code::

  snippet em
  	\emph{${1}}
  snippet s
  	\strong{${1}}
  snippet i
  	\textit{${1}}
  snippet b
  	\textbf{${1}}
  snippet u
  	\underline{${1}}
  snippet t
  	\texttt{${1}}
  snippet begin
  	\begin{${1:env}}
  		${2}
  	\end{$1}
  snippet enum
  	\begin{enumerate}
  		\item ${1}
  	\end{enumerate}
  snippet item
  	\begin{itemize}
  		\item ${1}
  	\end{itemize}



External Snippets
=================

If you would like to use community-maintained snippets, install `vim-snippets`_.

It has a collection of snippets ``vim-minisnip`` should be able to work with as a fork of ``snipMate.vim``.

.. _vim-snippets: https://github.com/honza/vim-snippets
