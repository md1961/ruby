
set encoding=utf-8
set fileencoding=utf-8

set tabstop=2
set shiftwidth=2
set expandtab

set nobackup

filetype on
filetype indent on
filetype plugin on

ab rdarg call RdocArgs()

scriptencoding utf-8

"
" Function to insert rdoc for method arguments from its definition
"
function RdocArgs()

  " Delimiter of arguments in method definition
  let s:delim = ", "

  " Remember current line number
  let s:orig_linenum = line(".")

  " Move 1 line up
  call cursor(s:orig_linenum - 1, 1)

  " Regexp for method difinition
  let s:re_method_def = "^ *def  *[^ ][^ ]*"

  " look for method difinition
  let s:is_found = search(s:re_method_def)
  let s:line_num = line(".")
  if ! s:is_found || s:line_num != s:orig_linenum
    echo "Cannot find method definiton in cursor line."
    call cursor(s:orig_linenum, 1)
    return
  end

  " Method definiton found
  let s:a_line = getline(".")
  let s:indent = StrRepeat(" ", stridx(s:a_line, "def "))
  let s:pos_paren0 = stridx(s:a_line, "(")
  let s:pos_paren1 = stridx(s:a_line, ")")
  let s:strlist_args = strpart(s:a_line, s:pos_paren0 + 1, s:pos_paren1 - s:pos_paren0 - 1)

  " Split strlist_args and write a line to explain an argument
  let s:line_num = s:line_num - 1
  let s:work_str = s:strlist_args
  while strlen(s:work_str) > 0
    " Locate delimiter
    let s:pos_delim = stridx(s:work_str, s:delim)
    if s:pos_delim == -1
      let s:pos_delim = strlen(s:work_str)
    end
    " Get next argument name
    let s:arg_name = strpart(s:work_str, 0, s:pos_delim)
    " Write an argument explanation line
    call s:WriteLineInRdocArgs(s:arg_name, s:line_num, s:indent)
    " Next line postion to write is one below
    let s:line_num = s:line_num + 1
    " Next target is the rest of the string
    let s:work_str = strpart(s:work_str, s:pos_delim + strlen(s:delim))
  endwhile

  " Write a return value explanation
  call append(s:line_num, s:indent . "# 返り値 :: ")
  let s:line_num = s:line_num + 1

  "echo "Got [" . s:strlist_args . "] (" . s:pos_paren0 . ", " . s:pos_paren1 . ")" . ", s:indent = " . pos_def
endfunction

" Helper function for function RdocArgs to write a line for argument explanation
function s:WriteLineInRdocArgs(arg_name, line_num, indent)
  " See if a default value is given, and keep it if given
  let s:default = ''
  let s:pos_equal = stridx(a:arg_name, '=')
  if s:pos_equal > 0
    let s:arg_name = strpart(a:arg_name, 0, s:pos_equal)
    let s:default  = strpart(a:arg_name, s:pos_equal + 1) 
  endif
  " Remove heading '*' or '&' from arg_name
  let s:char_heading = strpart(a:arg_name, 0, 1)
  if s:char_heading == '*' || s:char_heading == '&'
    let s:arg_name = strpart(s:arg_name, 1, strlen(s:arg_name))
  endif
  " Construct a line and write
  let s:a_line = a:indent . "# <em>" . s:arg_name . "</em> :: "
  if s:default > ''
    let s:a_line = s:a_line . 'デフォルトは ' . s:default
  endif
  call append(a:line_num, s:a_line)
endfunction

"
" Return a string in which repeat 'str' 'times' times
"
function StrRepeat(str, times)
  let s:retval = a:str
  let s:i = a:times - 1
  while s:i > 0
    let s:retval = s:retval . a:str
    let s:i = s:i - 1
  endwhile
  return s:retval
endfunction

