Navigation
----------
%   		Match x
*   		Next occurrence
#   		Previous occurrence of text
g*  		Next occurrence (part of text)
g#  		Previous occurrence (part of text)
gd		Go to definition (local scope)
gD		Go to definition (global scope)
g,  		Go forward to latest edit
g;		Go backward to latest edit
gg		Go to top of buffer
G		Go to bottom of buffer
[		Go to next method/section/paragraph
{		Go to next method/section/paragraph
(		Go to next method/section/paragraph
S		Replace line
s		Replace char
.		Repeat latest edit

Registers
---------
“a y		Yank into register a (replace)
“A y		Yank into register A (append)
“a p		Paste from register a
:registers	Show all registers

Buffers
-------
,t		Fuzzy find file
C-w o        	Maximize buffer
C-tab		Next buffer
C-S-tab		Previous buffer
,bn		Next buffer
,bp		Previous buffer
,bc		Close buffer
,ba		Close all buffers

Windows
-------	
C-w C-w		Go to next window
C-l		Go to right window
C-h		Go to left window
C-j
C-k

Marks
-----
m<register> 	Set bookmark
'<register> 	Go to bookmark
:marks		Show bookmarks
:delmarks a b c	
:delmarks!

Tags
----
match color /FIXME/
:tags		Show all tags
C-]
C-t

NERDTree
--------
,nt		Toggle NERDTree
B		Show bookmarks
C		Set dir as top dir 
cd		Set dir as working dir
O		Open file/folder
m		Show menu

LustyJuggler
------------
,lj		(Quick) jump to open buffer (LustyJuggler)
,lb		Jump to buffer (LustyJuggler)
,lf		Jump to file (LustyJuggler)

Compiling
---------
C-B		Build
C-L		Show error list
,cc		Show cope (error list)
,n		Jump to next error
,p		Jump to previous error


Misc
----
,cd		Set current file dir to current dir
gq <movement>	Format section over ‘movement’
,w		Save buffer
h1, h2, h3	Create reST style headings
gg=G		Format the whole buffer
,e		Edit vimrc
,t2		Set shiftwidth to 2 (t2 or t4)
,q		Open scratchpad
,m		Remove Windows ^M

Grep/Search
----
space		Search backwards
C-space		Search forwards
,g		Vimgrep
:vimgrep /pattern/[j][g] filepattern (use j for listing in quicklist)

Undo branching
--------------
g-		Traverse all undos backwards
g+		Traverse all undos forwards
:undolist	List all undo branches
:undo N		Undo to number N in list
:earlier Ns
:earlier Nm
:earlier Nh
:later Ns
:later Nm
:later Nh

Remote
------
:Nread remote.server.com jboner PASSWD path
:Nwrite remote.server.com jboner PASSWD path
vim ftp://...

Diff
----
vim -d f1 f2	Diff files
:diffsplit file	
:vert diffsplit file

Spelling
--------
,ss		Toggle spelling
,sn		Next error
‘sp		Previous error
Folding
-------
zc		Close fold
zo		Open fold
zM		Close all folds
zR		Open all folds
za		Toggle fold
‘z		Toggle fold
