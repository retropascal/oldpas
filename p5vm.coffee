###
coffeescript implementation of a the p5 virtual machine

This file is part of the "oldpas" ISO pascal compiler
Copyright (c) 2014 michal j wallace

Available under the MIT license at:

  https://github.com/retropascal/oldpas

technical references:
  online book about the interpreter (for older version but still relevant)
    http://homepages.cwi.nl/~steven/pascal/book/pascalimplementation.html
  recent p5 pascal implementation this file is based on:
    https://github.com/retropascal/oldpas/blob/master/p5/pint.pas
  for full docs, test suite, etc., see the p5 subversion repo:
    https://www.assembla.com/code/pascal-p5/subversion/nodes/55/trunk
###

assert = (truth, assertion)->
  if not truth then throw 'assertion failed: ' + assertion

###
p-code instruction set 
----------------------
instruction format (1..6 bytes):

  position: 0123456    o = opcode  P argument (0..1 byte)
  used for: oPQQQQQ                Q argument (0..4 bytes)

in the table below, the format is:

  opcode mnemonic len(P) typ(Q) * 4 per line
 
codes for typ(Q):

  _: none  I: integer  B: boolean  C: char

###
read_mnemonics = (tblstr) -> 
  ###
  :: str -> (isym:[str],lenP:[int],lenQ:[int]
  for each p-code operation (a number in [0..175]):
    isym[op] contains instruction symbols (mnemonics) for the assembler
    lenP contains the length in bytes (0 .. 1) of the P argument
    lenQ contains the length in bytes (0 .. 4) of the Q argument
  ###
  tokens = (t for t in tblstr.replace(/^\s+/,'').split /\s+/ )
  isym = [] ; lenP = [] ; lenQ = []
  op = -1 # 0 % 4 = 0 so op++ gets called for first token
  for i in [0..tokens.length-1]
    switch i % 4
      when 0 then op++ ; assert op == isym.length, 'op++ == length @ each record'
      when 1 then isym.push tokens[i]
      when 2 then lenP.push parseInt(tokens[i])
      when 3 then lenQ.push parseInt(tokens[i])
  return [isym, lenP, lenQ]

[isym, lenP, lenQ] = read_mnemonics (    # from p5/pint.pas lines 836-1010
   """ 
      0 lodi  1 I      l doi   0 I      2 stri  1 I      3 sroi  0 I
      4 lda   1 I      5 lao   0 I      6 stoi  0 _      7 ldc   0 I
      8 ---   0 _      9 indi  0 I     10 inci  0 I     11 mst   1 _
     12 cup   1 I     13 ents  0 I     14 retp  0 _     15 csp   0 I
     16 ixa   0 I     17 equa  0 _     18 neqa  0 _     19 geqa  0 _
     20 grta  0 _     21 leqa  0 _     22 lesa  0 _     23 ujp   0 I
     24 fjp   0 I     25 xjp   0 I     26 chki  0 I     27 eof   0 _
     28 adi   0 _     29 adr   0 _     30 sbi   0 _     31 sbr   0 _
     32 sgs   0 _     33 flt   0 _     34 flo   0 _     35 trc   0 _
     36 ngi   0 _     37 ngr   0 _     38 sqi   0 _     39 sqr   0 _
     40 abi   0 _     41 abr   0 _     42 not   0 _     43 and   0 _
     44 ior   0 _     45 dif   0 _     46 int   0 _     47 uni   0 _
     48 inn   0 _     49 mod   0 _     50 odd   0 _     51 mpi   0 _
     52 mpr   0 _     53 dvi   0 _     54 dvr   0 _     55 mov   0 I
     56 lca   0 I     57 deci  0 I     58 stp   0 _     59 ordi  0 _
     60 chr   0 _     61 ujc   0 I     62 rnd   0 _     63 pck   0 I
     64 upk   0 I     65 ldoa  0 I     66 ldor  0 I     67 ldos  0 I
     68 ldob  0 I     69 ldoc  0 I     70 stra  1 I     71 strr  1 I
     72 strs  1 I     73 strb  1 I     74 strc  1 I     75 sroa  0 I
     76 sror  0 I     77 sros  0 I     78 srob  0 I     79 sroc  0 I
     80 stoa  0 _     81 stor  0 _     82 stos  0 _     83 stob  0 _
     84 stoc  0 _     85 inda  0 I     86 indr  0 I     87 inds  0 I
     88 indb  0 I     89 indc  0 I     90 inca  0 I     91 incr  0 I
     92 incs  0 I     93 incb  0 I     94 incc  0 I     95 chka  0 I
     96 chkr  0 I     97 chks  0 I     98 chkb  0 I     99 chkc  0 I
    100 deca  0 I    101 decr  0 I    102 decs  0 I    103 decb  0 I
    104 decc  0 I    105 loda  1 I    106 lodr  1 I    107 lods  1 I
    108 lodb  1 I    109 lodc  1 I    110 rgs   0 _    111 fbv   0 _
    112 ipj   1 I    113 cip   1 _    114 lpa   1 I    115 efb   0 _
    116 fvb   0 _    117 dmp   0 I    118 swp   0 I    119 tjp   0 I
    120 lip   1 I    121 ---   0 _    122 ---   0 _    123 ldci  0 I
    124 ldcr  0 I    125 ldcn  0 _    126 ldcb  0 B    127 ldcc  0 C
    128 reti  0 _    129 retr  0 _    130 retc  0 _    131 retb  0 _
    132 reta  0 _    133 ordr  0 _    134 ordb  0 _    135 ords  0 _
    136 ordc  0 _    137 equi  0 _    138 equr  0 _    139 equb  0 _
    140 equs  0 _    141 equc  0 _    142 equm  0 I    143 neqi  0 _
    144 neqr  0 _    145 neqb  0 _    146 neqs  0 _    147 neqc  0 _
    148 neqm  0 I    149 geqi  0 _    150 geqr  0 _    151 geqb  0 _
    152 geqs  0 _    153 geqc  0 _    154 geqm  0 I    155 grti  0 _
    156 grtr  0 _    157 grtb  0 _    158 grts  0 _    159 grtc  0 _
    160 grtm  0 I    161 leqi  0 _    162 leqr  0 _    163 leqb  0 _
    164 leqs  0 _    165 leqc  0 _    166 leqm  0 I    167 lesi  0 _
    168 lesr  0 _    169 lesb  0 _    170 less  0 _    171 lesc  0 _
    172 lesm  0 I    173 ente  0 I    174 mrkl* 0 I
  """)


# ui for jsfiddle : http://jsfiddle.net/tangentstorm/RpnJh/
if typeof d3 isnt 'undefined'
  d3.select('output').text(isym.join ' ')
  pcode = d3.select('#pcode').text()
  status = 'coffeescript program loaded successfully.'
  console.log status ; d3.select('#status').text status
