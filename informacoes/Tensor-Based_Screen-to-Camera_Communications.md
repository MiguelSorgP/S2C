

## IEEE COMMUNICATIONS LETTERS, VOL. 27, NO. 10, OCTOBER 20232787
Tensor-Based Screen-to-Camera Communications
Leandro R. Ximenes,Member, IEEE, and Matheus F. Alves
Abstract— The  next  decade  holds  great  promise  for  Optical
Camera Communications (OCC) and its Screen-to-Camera (S2C)
application. On the one hand, the screen market has experienced
rapid growth in recent years, whereas the digital camera market
has  reached  levels  of  market  penetration  unrivaled  by  other
electronic devices. This letter proposes an S2C scheme based on
the  PARAFAC  decomposition  that  enables  the  joint  realization
of  three  important  tasks:  the  estimation  of  an  S2C  frame’s
image  degradation,  symbol  detection,  and  image  restoration  of
the  encoded  video.  Computer  simulations  show  that  using  a
developed semiblind receiver, these three steps, which are usually
performed  separately,  are  possible.  The  proposed  contributions
are  supported  by  a  practical  experiment  using  a  laptop  screen
and a smartphone camera. Finally, the letter derives the proposed
system’s  identifiability  and  uniqueness  conditions.
IndexTerms— Opticalwirelesscommunication,optical
camera,  screen-camera,  tensor  decompositions.
## I.  INTRODUCTION
## O
PTICAL  Camera  Communications  (OCC)  technology
uses  Image  Sensors  (IS),  which  are  found  in  many
digital  cameras  today,  to  receive  bits  transmitted  by  one  or
more  visible  light  sources  [1].  Because  of  the  growth  of
the  digital  camera  industry,  which  is  being  driven  by  the
increasing   prevalence   of   smartphones   across   a   variety   of
social  strata  and  geographic  locations,  OCC  technology  is  a
potential  optical  wireless  communication  technology  for  the
near future [2], [3].
In  Screen-to-Camera  (S2C)  implementations  of  the  OCC
technology,  when  a  digital  screen  is  used  as  a  transmitter,
the  misalignment  of  pixels  between  the  transmitter  and  the
receiver,  the  perspective  distortions  of  the  captured  scenes,
and  the  degradation  effects  (mainly  blur)  resulting  from  IS
resolution restrictions are additional issues [3].
Nevertheless,  OCC  communication  via  inexpensive  digital
cameras seems doable and promising [4]. Due to the fact that
the  baud  rate  in  an  OCC  system  is  frequently  related  to  the
frame rate of the camera (or transmitter, whichever is lower)
and  its  resolution,  OCC  communication  employing  cameras
with  a  resolution  on  the  order  of  Megapixels  is  tailored
for  many  applications,  including  indoor  tracking/positioning,
vehicle communications, and digital signage [3].
Simultaneously, the modeling of signals and systems based
on  tensor  decompositions  is  gaining  importance  in  order  to
better explore the numerous signal diversities present in mod-
ern  radiofrequency-based  systems  [5].  Each  signal  diversity
Manuscript  received  25  July  2023;  accepted  12  August  2023.  Date  of
publication  15  August  2023;  date  of  current  version  11  October  2023.
The  associate  editor  coordinating  the  review  of  this  letter  and  approv-
ing   it   for   publication   was   S.   K.   Jayaweera.(Corresponding   author:
## Leandro R. Ximenes.)
The   authors   are   with   the   School   of   Technology,   State   University   of
Campinas   (UNICAMP),   Campinas   13484-332,   Brazil   (e-mail:   leandro@
ft.unicamp.br; m241739@dac.unicamp.br).
Digital Object Identifier 10.1109/LCOMM.2023.3305836
(e.g.,   space/time/frequency)   to   be   exploited   is   related   to
a  dimension  of  the  signal  tensor  (multidimensional  array)
formed   by   the   receiver,   where   the   diversities   are   mostly
generated  by  coding  processes  at  the  sources.  Thus,  trans-
mission  system  parameters  of  interest,  such  as  the  symbol
and  channel  matrices,  are  factors  that  can  be  retrieved  from
the received signals under more relaxed conditions than those
associated with previous approaches that used a strictly matrix
formulation.
This   letter   describes   an   S2C/OCC   coding   system   that
is  based  on  the  PARAFAC  tensor  decomposition  [6].  This
approach  is  novel  in  the  scientific  literature  because  it  intro-
duces  space-time  tensor  coding  to  an  OCC  communication
scheme.  On  the  basis  of  this  new  multilinear  modeling,  the
degradation, native digital video, and symbol matrices can be
described as matrix factors of a third-order PARAFAC model.
This letter provides contributions not found in other works:
1)  The image degradation process can be jointly estimated
and  mitigated  by  the  receiver.  Simulations  involving
defocus   and   motion   blur   demonstrate   this   capacity,
which is not predicted by standardized schemes like the
Hidden Asynchronous Quick Link (HA-QL) [1];
2)  Symbol detection is accomplished without the need for
an  earlier  image  restoration  over  the  encoded  video.
Standardized OCC schemes do not address joint image
restoration, and very few works have attempted to com-
bat  blurring  in  a  supervised  manner.  In  [7],  deblurring
in  OCC  is  accomplished  with  a  Convolutional  Neural
Network (CNN), but data detection and video restoration
are  not  considered.  In  [8],  a  Weiner  filter  is  applied  in
S2C  systems  to  equalize  blurring,  but  assuming  priori
perfect knowledge of the degradation process;
3)  the  effects  of  defocus  and  motion  blurring  are  exam-
ined  numerically,  showing  that  they  may  result  in  rank
degeneration of the degradation matrix, thereby limiting
diversity gains.
Besides  simulations,  a  low-cost  testbed  involving  a  laptop
display as a transmitter and a smartphone camera as a receiver
is used to confirm the validity of the proposed scheme. In the
appendix of this letter, propositions are derived regarding the
uniqueness and identifiability of the models.
A.  Notations and Fundamentals
Scalars, matrices, and tensors are denoted by lower-case(x),
boldface capital(X), and calligraphic(X)letters, respectively.
## X
## T
andX
## †
are  the  transpose  and  the  pseudoinverse  ofX,
while
b
Xdenotes   an   eventual   estimate.   For   a   third-order
tensorX ∈C
## I
## 1
## ×I
## 2
## ×I
## 3
with  a  PARAFAC  [6]  decomposition
## X= [[A
## (1)
## ,A
## (2)
## ,A
## (3)
;R]], its mode-iunfolding is given by
## X
## (i)
## =
## 
## A
## (k)
## ⋄A
## (j)
## 
## A
## (i)
## 
## T
## ,(1)
1558-2558 © 2023 IEEE. Personal use is permitted, but republication/redistribution requires IEEE permission.
See https://www.ieee.org/publications/rights/index.html for more information.
Authorized licensed use limited to: Universidade Estadual de Campinas. Downloaded on July 15,2026 at 16:59:45 UTC from IEEE Xplore.  Restrictions apply.

## 2788IEEE COMMUNICATIONS LETTERS, VOL. 27, NO. 10, OCTOBER 2023
where⋄is  the  Khatri-Rao  product  operator,{(i,j,k)}=
{(1,2,3); (2,3,1); (3,2,1)},  andRis  the  PARAFAC  rank
and  the  number  of  columns  ofA
## (i)
## ∈C
## I
i
## ×R
.  The  powerful
essential uniqueness property of the PARAFAC decomposition
is summarized in Theorem 1.
Theorem 1 (c.f. [6]):  Given  the  modelX= [[A
## (1)
## ,A
## (2)
## ,
## A
## (3)
;R]],  the  essential  uniqueness  of  the  PARAFAC  decom-
position   means   that   its   matrix   factors   are   unique   up   to
column  scaling  and  permutation  ambiguities,  i.e.,  there  is  a
permutation  matrixΠand  diagonal  scaling  matricesΛ
## A
## ,
## Λ
## B
,  andΛ
## C
such  thatX= [[
b
## A
## (1)
## ,
b
## A
## (2)
## ,
b
## A
## (3)
;R]],  where
## Λ
## A
## Λ
## B
## Λ
## C
## =I
## R
## ,
b
## A
## (1)
## =A
## (1)
## ΠΛ
## A
## ,
b
## A
## (2)
## =A
## (2)
## ΠΛ
## B
, and
b
## A
## (3)
## =A
## (3)
## ΠΛ
## C
## .
A sufficient uniqueness condition is given as follows:
Theorem 2 ([9]):  GivenX=  [[A
## (1)
## ,A
## (2)
## ,A
## (3)
;R]],  let
## I
## 1
≥Rand  min(I
## 2
## ,I
## 3
)≥3.  Then  this  decomposition  is
essentially unique, almost surely, if(I
## 2
## −1)(I
## 3
## −1)≥R.
## II.  PROPOSEDTENSOR-BASEDOCC/S2C SYSTEM
Consider  that  the  imagey
f
is  thef-th  vectorized  frame
of  a  digital  video  composed  ofFframes.  Assume  also  that
the  degradation  process  is  time-invariant  during  the  entire
image acquisition interval, such that forf∈ {1,···,F}, the
captured framey
f
## ∈R
## MN×1
can be rewritten in the form of
y
f
=Hx
f
, wherex
f
## ∈R
## JL×1
is the respective undegraded
frame.J×LandM×Npixels are respectively the resolutions
of the original and of the degraded frames.
Without  loss  of  generality,  suppose  that  the  degradation
matrixHrepresent  linear  image  degradation  phenomena,
such  as  defocus  or  linear  motion  blur  [10],  [11],  as  well  as
the  Line-of-Sight  (LOS)  channel  Direct  Current  (DC)  gain
of  the  OCC  link  [12].  For  zero-boundary  conditions,  the
degradationHis likely a Block Toeplitz matrix with Toeplitz
Blocks  (BTTB)  [10],  [13].  Nonlinear  processes  like  Gamma
correction are ignored.
The S2C-encoding  proposed in this  article is based  on the
Khatri-Rao  Space-Time  (KRST)  coding  [14],  such  that  we
have the following coded video
## ̄
## X= (S⋄X)∈R
## F K×JL
## ,(2)
whereX≜[x
## 1
x
## 2
## ···x
## F
## ]
## T
## ∈R
## F×JL
is the uncoded video,
andS≜[s
## 1
s
## 2
## ···s
## K
## ]
## T
## ∈R
## K×JL
is  the  symbol  matrix
containing the symbols to be encoded ontoX. The operation
on  (2)  ensures  that  allJLpixels  of  the  original  video  are
individually  encoded  with  the  symbols  stored  withinS.  This
Khatri-Rao  product  is  responsible  for  the  generation  ofK
subframes within theFframes of the uncoded video.
The (noiseless) degraded videoYgenerated by the Image
Sensor (IS) is given by
## Y=H
## ̄
## X=H(S⋄X)
## T
## ∈R
## MN×F K
## ,(3)
where the rows ofYrepresent the spatial domain (i.e., pixels)
and its columns the time domain (i.e., video frames).
Comparing  (3)  with  (1),  and  making  the  correspondence
##  
## X
## (1)
## ,A
## (1)
## ,A
## (2)
## ,A
## (3)
## ,R
## 
⇔(Y,H,X,S,JL)between
them,   one   can   define   a   third-order   PARAFAC   model
## Y ∈R
## MN×F×K
asY≜[[H,X,S,JL]],  whose  mode-1,
Fig. 1.    Proposed S2C system. The OCC-ALS receiver applies a PARAFAC
decomposition on the block of received video frames.
mode-2, and mode-3 unfoldings can be respectively given by
## Y
## (1)
## = (S⋄X)H
## T
## ∈R
## F K×MN
## ,(4)
## Y
## (2)
## = (H⋄S)X
## T
## ∈R
## KMN×F
## ,(5)
## Y
## (3)
## = (X⋄H)S
## T
## ∈R
## MNF×K
## .(6)
Fig. 1 shows the block diagram of the proposed S2C system.
Considering the presence of additive noise, the noisy model of
i-th unfolding is given by
e
## Y
## (i)
## =Y
## (i)
## +N
## (i)
## ,i={1,2,3},
whereN
## (1)
## ∈R
## F K×MN
## ,N
## (2)
## ∈R
## KMN×F
,  andN
## (3)
## ∈
## R
## MNF×K
are unfoldings of the related noise tensorN.
## III.  OCC-ALS RECEIVER
The  proposed  semi-blind  receiver  OCC-ALS  in  Alg.  1  is
capable  of  estimatingH,XandSfrom
e
Yin  an  iterative
fashion. The base Alternating Least Squares (ALS) is a classic
iterative  algorithm  proper  for  estimating  matrix  factors  in
tensor decompositions [5].
Within   itsi-th   iteration,   and   until   its   convergence,
OCC-ALS   sequentially   find   thei-th   estimates   ofH,S
andXby   Least   Squares   (LS)   minimization   of   three
quadratic   cost   functions   based   on   (4)-(6).   The   instanta-
neous   errorε
i
of   Alg.   1,   can   be   calculated   byε
i
## =



e
## Y
## (3)
## −
## 
b
## X
i
## ⋄
b
## H
i
## 
b
## S
## T
i



## 2
## F
## /



e
## Y
## (3)



## 2
## F
## .
Algorithm  1OCC-ALS
1:Initializei=0,
b
## S
## 0
## ,
b
## X
## 0
, and seti
max
2:Fori= 1,2,···,i
max
, find iteratively
b
## H
i
## ,
b
## S
i
, and
b
## X
i
: a.
## 1)(
b
## H
i
## )
## T
## =
## 
b
## S
i−1
## ⋄
b
## X
i−1
## 
## †
e
## Y
## (1)
## 2)(
b
## X
i
## )
## T
## =
## 
b
## H
i
## ⋄
b
## S
i−1
## 
## †
e
## Y
## (2)
## 3)(
b
## S
i
## )
## T
## =
## 
b
## X
i
## ⋄
b
## H
i
## 
## †
e
## Y
## (3)
4)  Stop convergence ifε
i
## ≤10
## −6
3:Remove  ambiguity  matrixΠby  ordering  the  setRin
(15) accordingly to the setSin (14).
4:Find the column scaling ambiguities by Proposition 4:
## ∆
## X
## =diag
## −1
## (x
k
## )diag(
b
x
k
## ),∆
## S
## =diag
## −1
## (s
k
## )diag(
b
s
k
## ).
5:Remove column scaling ambiguities:
b
## X←
b
## X∆
## −1
## X
## ,
b
## S←
b
## S∆
## −1
## S
## ,
b
## H←
b
## H∆
## S
## ∆
## X
## .
The   complexity   of   the   OCC-ALS   algorithm   is   mainly
related   to   the   number   of   pseudoinverse   operations   in
Step   2   of   Alg.1.   As   the   complexity   of   the   SVD   of   a
Authorized licensed use limited to: Universidade Estadual de Campinas. Downloaded on July 15,2026 at 16:59:45 UTC from IEEE Xplore.  Restrictions apply.

## XIMENES AND ALVES: TENSOR-BASED SCREEN-TO-CAMERA COMMUNICATIONS2789
## Fig. 2.   Estimated
b
Hfor two levels of blurring with averaging kernel matrices.
## I
## 1
## ×I
## 2
matrix  isO
##  
max(I
## 1
## ,I
## 2
## )
## 2
min(I
## 1
## ,I
## 2
## )
## 
[15],  then  the
approximately  complexity  of  single  iteration  of  OCC-ALS
is  given  byO
##  
## F
## 2
## K
## 2
## JL+F
## 2
## M
## 2
## N
## 2
## JL+M
## 2
## N
## 2
## K
## 2
## JL
## 
## .
These   parameter   values   are   constrained   in   accordance
with   Proposition   1,   which   addresses   the   identifiability
by OCC-ALS.
## IV.  COMPUTATIONALVALIDATION
In  this  section,  Monte  Carlo  validation  of  the  proposed
scheme is presented, including verification of the degradation
matrix estimation, calculation of the bit error rate, and restora-
tion  error  of  the  encoded  video.  In  Section  V,  experimental
results  for  a  practical  S2C  communication  platform  utilizing
a laptop screen and a smartphone camera are presented.
Only  grayscale  synthetic  videos  are  used,  and  the  entries
ofXare independently drawn from a continuous Uniform dis-
tributionU(0,A), withA= 1representing the maximum pixel
intensity  (i.e.,  brightest  white).  Perfect  transmitter-reception
frame  synchrony  and  Region  of  Interest  (RoI)  identification
without perspective distortions are assumed.
Symbols are randomly drawn from a simple On-Off Keying
(OOK)  alphabet  [1],  in  an  equiprobable  manner.  For  each
simulated  BER  or  NMSE  value,  100  Monte  Carlo  runs  are
performed.  Symbol  and  video  estimates  are  initialized  as
all-ones  matrices  in  OCC-ALS  for  every  Monte  Carlo  run.
The algorithm is set to stop atε
i
## ≤10
## −6
## .
Defocus  blurring  was  simulated  with  an  averaging  filter
with  a  kernel  of2×2and3×3pixels,  with  zero-boundary
conditions.  Motion  blurring  simulates  the  linear  motion  of  a
camera  byσ∈ {2,3}pixels  diagonally,  with  an  angle  of
45  degrees  in  a  counter-clockwise  orientation.  The  blurring
processes were generated using spatial convolution operation.
Simulated   Signal-to-Noise   Ratio   (SNR)   is   given   by
## SNR=∥Y∥
## 2
## F
## /∥N∥
## 2
## F
, where the Frobenius norm of a tensor is
defined in [5]. For every Monte Carlo run, the average symbol
energy is kept constant, and only the additive white Gaussian
noise  power  is  adjusted  to  the  proper  SNR.  The  DC  channel
gain  with  its  parameters  (e.g.,  distance  and  optical  path  loss
coefficient [12]) is left as a part of the symbol energy.
For  non-negligible  blurring,Hmust  be  estimated  or  com-
pensated  [10].  While  conventional  S2C  scheme  like  HA-QL
and A-QL neglects this procedure [1], the OCC-ALS algorithm
allows its joint estimation with
b
## Xand
b
Sin its routine.
Fig.   2   shows   the   visual,   top-view   estimates   of
b
## H
for   different   degrees   of   defocus   blurring   (e.g.,   different
averaging masks). SNR at the output of the IS is set to 100 dB,
andJ=L=M=N= 6,K= 64,  andF= 20.
Notably, Fig. 2.(b) is unmistakably Block Toeplitz [10], [13],
Fig. 3.Degradation (channel) and video NMSE.
Fig. 4.BER for different levels of blurring.
corroborating  the  expected  results.  The  lack  of  blurring  was
also successfully estimated as
b
His nearly an identity matrix
(Fig. 2.(a)).
Fig.  3  depicts  the  performance  of  the  channel  (Fig.  3.(a))
and video (Fig. 3.(b)) estimations in terms of the Normalized
Mean  Square  Error  (NMSE)  given  by  NMSE=E{∥A−
b
## A}∥
## 2
## F
## /E{∥A∥
## 2
## F
}, whereA={H,X}.His built using the
coefficients of the blur kernels into the BTTB matrices [10].
Fig. 3 demonstrates that when the SNR is sufficiently high,
OCC-ALS  correctly  estimates  the  degradation  matrix  and
restores  the  encoded  video.  In  addition,  the  linear  behavior
of  the  NMSE  curves  is  consistent  with  the  factor  estimation
of a PARAFAC decomposition by an ALS algorithm [5].
While  the  comparison  of  the  two  types  of  blurring  is
largely irrelevant in this figure, it is important to note that the
estimation error increases as the degree of blurring increases.
In  any  case,  every  10  dB  increase  in  SNR  resulted  in  a
two-decade reduction in both errors.
Fig.  4  depicts  the  significant  impact  of  blurring  on  the
BER  performance.  A  comparison  is  made  with  HA-QL  [1]
for  similar  code  rates,  i.e.,1/F= 1/20for  OCC-ALS  and
7/120for HA-QL due to its Forward Error Correction (FEC)
and  1/2-rate  line  coding.  Although  OCC-ALS  can  estimate
and  compensate  for  defocus  and  motion  blur  degradation,
performance  is  still  degraded  by  approximately  20  dB  in
the simulated scenarios. Clearly increasing the blurring effect
has  a  negative  impact  on  the  conditioning  numberηofH,
which  explains  the  performance  degradation.  Channel  (rank)
degeneracy is a major limiting factor for optical MIMO gains.
On  the  other  hand,  performance  can  still  be  satisfactory
in  systems  with  high  SNR,  which  is  fully  attainable  with
S2C  schemes.  When  compared  to  the  HA-QL,  this  scheme
Authorized licensed use limited to: Universidade Estadual de Campinas. Downloaded on July 15,2026 at 16:59:45 UTC from IEEE Xplore.  Restrictions apply.

## 2790IEEE COMMUNICATIONS LETTERS, VOL. 27, NO. 10, OCTOBER 2023
Fig. 5.Block diagram of the proposed testbed.
performs  better  for  higher  SNR  (i.e.,≥20dB)  due  to  the
use of FEC, but worse for lower SNR and significantly worse
in  the  presence  of  blurring.  Our  scheme  is  intuitively  the
best option for longer distance links where relative noise and
blurring are more prevalent [12].
## V.  S2C TESTBED
To  show  the  real-world  viability  of  the  proposed  scheme,
an   accessible   testbed   for   S2C/OCC   systems   was   created
(Fig.  5).  On  the  transmitting  side,  a  Dell  Inspiron  5458  was
deployed to display the video frames. Its 14-inch WLED HD
display  features  a  resolution  of  1366  by  768  pixels  and  a
refresh rate of 60 Hz. In order to capture the encoded videos,
a  Motorola  Moto  G7  Play  smartphone  was  deployed  as  the
receiver.
In this experiment, the noiseNis generically modeled by
## N=N
## AW GN
## +N
## Art
,  whereN
## AW GN
is  the  real-world
additive   white   Gaussian   noise,   andN
## Art
is   an   artificial
software-controlled  noise.  Sampling  noises,  ambient  lighting
noise, and other photo-based and dark-currents are ignored, but
they are considered present withinN
## AW GN
. UnlikeN
## Art
, the
power  ofN
## AW GN
is  assumed  to  be  constant  and  unknown.
## N
## Art
is  a  White  Gaussian  noise  with  zero  mean,  added  at
the output of the transmission, on the video displaying by the
laptop  screen.  At  the  time  of  the  experiment,  the  measured
external illumination level was 30 lux. In this section, (artifi-
cial) SNR is adjusted by SNR=∥Y∥
## 2
## F
## /∥N
## Art
## ∥
## 2
## F
## .
At  the  transmitter,4×4grids  were  utilized.  Under  a
screen  resolution  of1366×768pixels,  the  RoI  occupied
as  an  area  of  13  by  13  centimeters  on  the  laptop’s  screen.
On  the  receiving  end,  the  camera  was  fixed  at  a  320×240
(QVGA)  resolution,  with  a  distance  of  30  cm  between  the
camera and the laptop screen. Video blocks ofF= 10frames
were  used.  Screen  and  camera  rates  are  both  at  15  FPS.
Frame  synchronization  is  achieved  using  a  reference  frame
## (see Proposition 4).
Fig.  6  shows  a  perspective  view  of
b
Hfor  three  different
artificial SNR values. Without going into specifics, it is clear
that  as  the  SNR  rises,
b
Happroaches  an  identity  matrix
in Fig. 6.(b) – effectively, defocus blurring is mainly present
in long distance links, as in outdoor scenarios [12].
Fig. 7 demonstrates that OCC-ALS successfully converged
for  the  different  levels  of  artificial  SNR  (withi
max
## ≤110).
The BER values of each curve demonstrate that the proposed
scheme does work in practical scenarios, with a considerable
small BER around10
## −5
at SNR of 300 dB, where the added
Fig. 6.Degradation estimation in the experimental test.
Fig. 7.Convergence of OCC-ALS for different values of SNR.
noiseN
## Art
is  negligible.  Secondly,  the  minimum  achievable
BER  is indeed  limited by  uncontrollable sources  of degrada-
tion, such as the room lighting noises represented byN
## AW GN
## .
## VI.  CONCLUSION
This letter promotes a communication system based on the
PARAFAC decomposition to jointly estimate the image degra-
dation, the uncoded video, and the symbol matrix parameters
of  S2C  systems.  The  theoretical  contribution  of  this  letter
lies  in  the  system  model,  its  iterative  semi-blind  receiver,
and the derivation of identifiability and uniqueness conditions.
Numerical  simulations  show  that  the  OCC-ALS  receiver  can
successfully  estimate  these  three  factors,  even  in  the  pres-
ence  of  image  blurring,  highly  detrimental  to  conventional
S2C  matrix-based  schemes,  and  then  a  testbed  validates  the
contributions of this article in the real world. Due to the mul-
tidimensional nature of S2C applications, the benefits of tensor
decompositions, and the potential of this S2C technology, this
work  lays  the  foundation  for  the  development  of  new  tensor
approaches that are tailored to OCC/S2C systems.
## APPENDIX
## A.  Model Identifiability
Proposition 1 (Design for OCC-ALS):  LetHbe a full-rank
Toeplitz  matrix,Xa  random  matrix,  whose  pixel  intensities
are  sorted  out  from  a  continuous  uniform  distribution  in  the
grayscale  interval,  andSis  a  random  binary  matrix  with
min(K,MN)≫1.  A  sufficient  condition  for  system  identi-
fiability using OCC-ALS is that min(K+F−1,MN)≥JL.
Proof:The  minimizations  of  the  OCC-ALS  receiver
in  the  LS  sense  are  possible  only  if  the  respective  three
Khatri-Rao products are full column-rank:
rank(S⋄X) =rank(H⋄S) =rank(X⋄H) =JL.(7)
This is a necessary and sufficient condition.
Authorized licensed use limited to: Universidade Estadual de Campinas. Downloaded on July 15,2026 at 16:59:45 UTC from IEEE Xplore.  Restrictions apply.

## XIMENES AND ALVES: TENSOR-BASED SCREEN-TO-CAMERA COMMUNICATIONS2791
By   the   well-known   property   that   for   any   matricesA
andBone   has   that   rank(A⋄B)≥min(rank(A) +
rank(B)−1,C),  whereCis  the  number  of  columns  ofA
andB, then rank(A⋄B) =Cif rank(A)+rank(B)≥C+1.
Therefore,  (7)  is  satisfied  if  all  of  the  following  sufficient
conditions are true
rank(X) +rank(H)≥JL+ 1,(8)
rank(H) +rank(S)≥JL+ 1,(9)
rank(S) +rank(X)≥JL+ 1.(10)
IfHhas  full  rank  withMN≥JL,  then  (8)  and  (9)  are
satisfied  if  both  rank(S)≥1and  rank(X)≥1,  which  is
true  for  non-zero  matrices.  Moreover,  once  with  probability
close  to  one,  bothSandHhave  full  rank,  then  rank(S) =
min(K,MN)and  rank(X) =min(F,MN),  and  (10)  is
always satisfied ifK+F≥JL+ 1.□
## B.  Model Uniqueness
Proposition 2:  LetMN≥JLand  min(J,F)≥3.  Then,
the  proposed  PARAFAC  decomposition  ofYis  essentially
unique, almost surely, if(F−1)(K−1)≥JL.
Proposition  2  is  a  corollary  of  Theorem  2,  which  implies
by  Theorem  1  that  estimates(
b
## H,
b
## X,
b
S)are  unique  up  to
permutation and scaling ambiguities, i.e.,
b
## H=H∆
## −1
## X
## ∆
## −1
## S
## Π,
b
## X=X∆
## X
## Π,
b
## S=S∆
## S
## Π,(11)
where  the  diagonal  matrices∆
## X
and∆
## S
refer  to  scaling
ambiguities, andΠis a permutation matrix.
To eliminate permutation ambiguity, Proposition 3 specifies
a  strategy  involving  two  frames  of  the  uncoded  video.  The
premise  of  this  proposition  is  that  the  element-wise  ratio
between  two  subsequent  rows  ofXestablishes  a  monotonic
order that must be observed when estimating this matrix.
Proposition 3:  For any single framef∈{1,2,···,F−1},
let thef-th row vector ofXbe given by
x
f
## =
## 
ξ
## I
## JL−1
## 2I
## JL−1
## ···I
## 
## ∈R
## 1×JL
## ,(12)
whereIis  the  maximum  pixel  intensity  in  a  gray  scale,  and
x
f
(i)denotes  thei-th  element  of  (12).  Let  alsox
f+1
## (i) =
x
f
(JL−i+ 1)fori= 1,2,···,JL. Under such hypotheses,
for a small numberξ, thenΠis an identity matrix if
γ
t
## ≜
b
x
f
## (t)
b
x
f+1
## (t) +ξ
## ≥γ
t−1
∀t∈{2,···,JL}.(13)
Proof:Given the hypotheses onx
f
andx
f+1
, then the
set
## S=
## 
x
f
## (1)
x
f+1
## (1) +ξ
## ,···,
x
f
## (JL)
x
f+1
(JL) +ξ
## 
## (14)
is monotonically crescent. Therefore, with probability close to
one, it yields for any∆
## X
that
b
## Π=I
## JL
if the set
## R=
## 
b
x
f
## (1)
b
x
f+1
## (1) +ξ
## ,···,
b
x
f
## (JL)
b
x
f+1
(JL) +ξ
## 
## (15)
is also monotonically crescent, as at convergenceR≈S.□
Proposition 4:  Let   one   row   ofSand   one   row   ofX,
denoted  ass
k
andx
f
respectively,  be  known  and  without
zeros. Consequently, all scaling ambiguities of(
b
## H,
b
## X,
b
## S)can
be  eliminated,  with  only  one  frame  of
## ̄
Xas  a  reference
frame.
Proof:The  proof  is  straightforward.  Consider,  with-
out  loss  of  generality,  that  through  Proposition  3  one  has
already eliminated the permutation ambiguity. Therefore, (11)
becomes
b
## H=H∆
## −1
## X
## ∆
## −1
## S
## ,
b
## X=X∆
## X
## ,
b
## S=S∆
## S
## .(16)
From   (16),   one   has   diag(
b
x
f
## )  =diag(x
f
## )∆
## X
and
diag(
b
s
k
## )  =diag(s
k
## )∆
## S
## .  Ifx
k
ands
k
contain  no  zero
elements, then the diagonal matrices are invertible, yielding
## ∆
## X
## =diag
## −1
## (x
f
## )diag(
b
x
f
## ),∆
## S
## =diag
## −1
## (s
k
## )diag(
b
s
k
## ).
By  choosings
k
andx
f
to  be  known,  only  the(k,f)-th
frame of
## ̄
Xshould be used as a reference frame.□
## REFERENCES
[1]IEEE   Standard   for   Local   and   Metropolitan   Area   Networks—Part
15.7:Short-RangeOpticalWirelessCommunications,
IEEE Standard 802.15.7-2018, pp. 1–407, 2019.
[2]  Z. Zhang et al., “6G wireless networks: Vision, requirements, architec-
ture,  and  key  technologies,”IEEE  Veh.  Technol.  Mag.,  vol.  14,  no.  3,
pp. 28–41, Sep. 2019.
[3]  N.  Saeed,  S.  Guo,  K.-H.  Park,  T.  Y.  Al-Naffouri,  and  M.-S.  Alouini,
“Optical  camera  communications:  Survey,  use  cases,  challenges,  and
future trends,”Phys. Commun., vol. 37, Dec. 2019, Art. no. 100900.
[4]  Y.  Li,  Z.  Ghassemlooy,  X.  Tang,  B.  Lin,  and  Y.  Zhang,  “A  VLC
smartphone  camera  based  indoor  positioning  system,”IEEE  Photon.
Technol. Lett., vol. 30, no. 13, pp. 1171–1174, Jul. 1, 2018.
[5]  N.D.Sidiropoulos,L.DeLathauwer,X.Fu,K.Huang,
E. E. Papalexakis,   and   C.   Faloutsos,   “Tensor   decomposition   for
signal processing and machine learning,”IEEE Trans. Signal Process.,
vol. 65, no. 13, pp. 3551–3582, Jul. 2017.
[6]  R.  Harshman,  “Foundations  of  the  PARAFAC  procedure:  Models  and
conditions  for  an  ‘explanatory’  multimodal  factor  analysis,”  UCLA,
Los Angeles, CA, USA, Tech. Rep. 16, 1970.
[7]  X.  Sun,  W.  Shi,  Q.  Cheng,  W.  Liu,  Z.  Wang,  and  J.  Zhang,  “An  LED
detection  and  recognition  method  based  on  deep  learning  in  vehicle
optical camera communication,”IEEE Access, vol. 9, pp. 80897–80905,
## 2021.
[8]  C.  Lin  et  al.,  “A  blur  equalization  method  for  screen-to-camera  based
optical camera communications,” inProc. 18th Int. Conf. Opt. Commun.
Netw. (ICOCN), 2019, pp. 1–3.
[9]  I.  Domanov  and  L.  D.  Lathauwer,  “Generic  uniqueness  conditions  for
the canonical polyadic decomposition and INDSCAL,”SIAM J. Matrix
Anal. Appl., vol. 36, no. 4, pp. 1567–1589, Jan. 2015.
[10]  Y.  W.  Fan  and  J.  G.  Nagy,  “Synthetic  boundary  conditions  for  image
deblurring,”Linear  Algebra  Appl.,  vol.  434,  no.  11,  pp. 2244–2268,
## Jun. 2011.
## [11]  P. Stanimirovi
## ́
c, M. Miladinovi
## ́
c, I. Stojanovi
## ́
c, and S. Miljkovi
## ́
c, “Appli-
cation  of  the  partitioning  method  to  specific  Toeplitz  matrices,”Int.
J.  Appl.  Math.  Comput.  Sci.,  vol.  23,  no.  4,  pp. 809–821,  Dec.  2013,
doi: 10.2478/amcs-2013-0061.
[12]  A.  Liu,  W.  Shi,  M.  Ouyang,  and  W.  Liu,  “Characterization  of  optical
camera   communication   based   on   a   comprehensive   system   model,”
J. Lightw. Technol., vol. 40, no. 18, pp. 6087–6100, Sep. 15, 2022.
[13]  M. K. Ng, R. H. Chan, and W.-C. Tang, “A fast algorithm for deblurring
models  with  Neumann  boundary  conditions,”SIAM  J.  Sci.  Comput.,
vol. 21, no. 3, pp. 851–866, Jan. 1999.
[14]  N.  D.  Sidiropoulos  and  R.  S.  Budampati,  “Khatri–Rao  space-time
codes,”IEEE  Trans.  Signal  Process.,  vol.  50,  no.  10,  pp. 2396–2407,
## Oct. 2002.
[15]  L. R. Ximenes, G. Favier, and A. L. F. de Almeida, “Closed-form semi-
blind receiver for MIMO relay systems using double Khatri–Rao space-
time  coding,”IEEE  Signal  Process.  Lett.,  vol.  23,  no.  3,  pp. 316–320,
## Mar. 2016.
Authorized licensed use limited to: Universidade Estadual de Campinas. Downloaded on July 15,2026 at 16:59:45 UTC from IEEE Xplore.  Restrictions apply.