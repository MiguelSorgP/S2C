

## Digital Signal Processing 141 (2023) 104192
Contents lists available atScienceDirect
## Digital Signal Processing
journal homepage: www.elsevier.com/locate/dsp
Integrated data detection and video restoration for optical camera
communications
## Leandro R. Ximenes
## ∗
## , Bruno A. Laredo, Rangel Arthur
State University of Campinas (UNICAMP), R. Paschoal Marmo 1888, Limeira, SP, 13484-332, Brazil
a r t i c l e i n f oa b s t r a c t
Article history:
Available online 16 August 2023
## Keywords:
Optical wireless communication
Signal processing
## Camera
Video signal processing
Optical Camera Communication (OCC) technology enables the use of Image Sensors (IS) with Visible
Light Communications (VLC), one of the key technologies for the Sixth Generation (6G) of mobile
communications. For Screen-to-Camera (S2C) applications in which Light-Emitting Diode (LED) screens
modulate information symbols onto video pixels, increasing either the (transmitted) image resolution or
frame rate may have a negative effect on the bit error performance and visual quality of OCC-encoded
videos. This work proposes a novel OCC/S2C coding approach that lets both symbol transmission and
video quality can be improved simultaneously. For this dual task, a Parallel Factor Analysis (PARAFAC)
decomposition is applied for the first time in the literature to model an OCC system. In addition to
validating the correct formulation of the proposed models, hypotheses, and algorithms, computational
simulations demonstrate that increasing the number of video frames can result in time diversity gains.
In accordance with the parameters of the system, this work also addresses the practical aspects of data
rate, data volume, and computational complexity of the receiver.
©2023 Elsevier Inc. All rights reserved.
## 1. Introduction
Optical Camera Communication (OCC) is a recent technology
with significant potential for rapid widespread implementation.
This technology was specified in [1]as a component of the Visible
Light Communication (VLC) standard. OCC differs from VLC in that
its receiver is not based on discrete photodiodes (PDs), but rather
on image sensors, which are commonly found in all modern cam-
eras
[2]. Since the market penetration of these devices is expected
to increase steadily over the next few years, the OCC technology
is highly attractive and has already been tested for a number of
applications, including vehicular communications [3,4], indoor lo-
cation
positioning/localization [5,6], broadcasting [7], and digital
signage, among others [8]. OCC and VLC as a whole are prospective
technologies for the Sixth Generation (6G) of wireless communica-
tions
## [9,10].
OCC systems can typically be categorized based on the number
of elements present at each end of the communication link. On the
source side, the Screen-to-Camera (S2C) category, also known as
display-camera ([11,12]) or simply screen-camera ([13]), predicts
the use of hundreds or thousands of screen pixels as transmitters
[8]. This technology has tremendous potential, as the number of
## *
Corresponding author.
E-mail address:ronchini@unicamp.br(L.R. Ximenes).
commercial digital screens has grown even faster than the num-
ber
of smartphones, driven by the market growth of these devices,
digital billboards, and modern display-based consumer electron-
ics
[14]. Image sensors on the receiver side are typically based
on Complementary Metal Oxide Semiconductor (CMOS) or Charge-
## Coupled
Device (CCD) technology.
OCC/S2C systems offer an innovative integration of wireless
communication and image processing. To guarantee the desired re-
liability,
data rate, latency, and other performance requirements,
the communication design must include the proper modulation
and coding schemes. For the concurrent task of video transmis-
sion,
the transmitter must encode the binary message into video
pixels without degrading the subjective visual quality perceived by
the human eye.
With the limitation of the camera’s frame rate, in the order of
a few dozen frames per second for low-cost cameras, the concept
of Optical Multiple-Input Multiple-Output (MIMO) is usually ex-
ploited
to enhance data rate. And, thanks to the high number of
LEDs on a screen and the high number of photodetectors present
in an image sensor, ultra-massive MIMO theoretical channel capac-
ity
can be achieved with S2C systems [13].
Despite these promising advantages, the dual transmission of
binary data and visual information affects the performance of an
S2C system in two distinct but related ways. The first involves the
so-called interpixel interference (IPI), which can be summed up as
the situation in which the light intensity of a pixel impedes the
https://doi.org/10.1016/j.dsp.2023.104192
1051-2004/©2023 Elsevier Inc. All rights reserved.

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
identification of the light intensity of its neighbors [15]. Moreover,
IPI can be related to both the blooming effect and traditional im-
age
degradation phenomena, such as optical blurring and motion
blurring. For the blooming effect, the luminosity of a given pixel
must be sufficient to illuminate the surrounding pixels. The works
[16,17]propose solutions to this problem. In this context, image
restoration techniques can mitigate the blurring effects caused by
the optical camera’s low resolution or capture rate. The second
issue is that embedding information symbols on the pixels of a
video has a negative visual impact. In contrast to the previous
issue, which was intrinsically caused by hardware limitations or
non-idealities of the optical channel, this issue is solely related to
OCC coding and modulation.
Several modulation schemes, coding techniques, and receiver
algorithms for OCC have been proposed in the past ([18,19] and
related works). Digital modulations including On-Off Keying (OOK),
Pulse Position Modulation (PPM), Quadrature Amplitude Modula-
tion
(QAM), and Color-Shift Keying (CSK) are implemented [20,21,
## 1],
as well as various sampling methods including Screen-Nyquist
sampling and Rolling-Shutter Nyquist sampling [1].
All of these modulations proposed for VLC or OCC systems have
inherent properties that affect the human visual system’s percep-
tion
of light to varying degrees. CSK modulation, for instance, pre-
vents
flickering by transmitting at constant power. In contrast, the
UFSOOK modulation handles flickering by transmitting at a sig-
nificantly
higher pulse rate than the camera’s capture rate [22].
Despite the fact that the acceptable threshold of screen flickering
is less critical in S2C systems [19], their satisfactory performance is
invariably also defined by the subjective visual quality degradation
caused by symbol-pixel coding [23].
Relevant new advances have been proposed in the area of
screen-to-camera communications in the last couple of years. For
instance, one can cite the scheme proposed by Fujihashi et al.
[13], as well as the Interframe++ [24], ChromaCode [25], and TERA
[26] systems. All these works propose complete S2C-based embed-
ding
systems, with symbol coding and sometimes involving ad-
ditional
steps of equalization, lighting correction, color treatment,
and eventually the use of convolutional networks, to satisfy spec-
tral
efficiency requirements, transparency of encoded data to the
human visual system, and robustness in different transmission sce-
narios.
At the same time, the use of tensor models has increased sig-
nificantly
over the past few decades, with applications in wire-
less
communications [27,28], signal processing, and machine learn-
ing
[29], Big Data analysis [30,31], biological and health studies
[32,33], and many other fields.
Relaxing parameter estimation conditions is possibly the great-
est
advantage of using tensors in system modeling. In wireless
communications, for instance, tensor modeling of the transmission
system typically enables the receiver to estimate symbol and chan-
nel
matrices from multidimensional signals under less stringent
conditions than matrix-based approaches.
Various tensor models have been proposed in the scientific lit-
erature.
Although the vast majority of decompositions have been
proposed within the last two decades ([29]), the PARAFAC de-
composition
[34]is likely the most well-known. In the trilinear
PARAFAC decomposition, it is possible to jointly estimate up to
three matrix factors, whose solutions are unique under certain re-
laxed
conditions.
## 1.1. Contributions
This work proposes a novel S2C/OCC system based on tensor
modeling. More precisely, employing space-time symbol-pixel cod-
ing,
for the first time the S2C/OCC technology has been treated
with a multilinear tensor coding. The proposed tensor-based ap-
proach enables the simultaneous execution of symbol detection
and video restoration in S2C/OCC systems, two tasks that have
never been jointly performed.
Briefly, the combination of tensor modeling in S2C/OCC systems
is responsible for the following contributions of this article:
•A OCC/S2C baseband coding system based on the PARAFAC de-
composition
is developed. In this work, information signals
encode each individual LED/pixel of a digital screen using a
Khatri-Rao Space-Time (KRST) coding [35]. Thus, arbitrary dig-
ital
video frames, such as from a movie, are encoded in blocks
by sequences of symbols to generate a video tensor. The ten-
sor’s
multidimensionality derives from the original video’s res-
olution,
its number of frames, and its number of symbols per
video block.
•For this scheme, the OCC Khatr-Rao Factorization (OCC-KRF)
algorithm is proposed as a non-iterative blind equalizer. OCC-
## KRF,
unlike other OCC receivers in the literature, has a unique
dual function: it simultaneously estimates information sym-
bols
and restores the captured video’s visual quality. In this
regard, there is no sacrifice of one task for another. In addition,
a computer simulation demonstrates that the symbol detection
performance of the proposed system outperforms that of Hid-
den
Asynchronous Quick Link (HA-QL) [1]even without the
use of error-correcting codes with our receiver in the presence
of strong noise.
•Formulas for data rate, generated data volume, and compu-
tational
cost is derived. There are proposed design rules to
ensure the essential uniqueness and identifiability of the pro-
posed
model. Moreover, it is demonstrated that the receiver
can easily avoid all ambiguities of the PARAFAC decomposition
if it only has access to a single (pilot) frame of the original
video.
1.2. Paper considerations
Due to its interdisciplinary nature (semiconductor device elec-
tronics,
image processing, tensor decompositions, and wireless
communication systems), this work adopts the following practical
simplifications:
•The pixel-based nature of our communication scheme should
be stressed. Therefore, various screen types (such as LEDs,
OLEDs, and LCDs) and image sensors can be utilized (e.g.,
CMOS and CCD). At this point, the non-idealities and non-
linearities
of these devices’ electronics are disregarded in our
modeling;
•It is assumed that the screen’s electro-optical transfer func-
tion
(OETF) is linear [36,37]. Eventually, a non-linear Gamma
correction can be applied to the video to be encoded by the
proposed method, without affecting the communication mod-
els
described in this work;
•This work does not address the synchronization issues of OCC
systems, commonly seen in CMOS cameras with rolling shutter
sampling. Methods for frame synchronization, such as those
provided in [1,11,19], are fully compatible with our proposed
system without the need for major framework modifications;
•The described system operates on a frame-by-frame basis in-
dependent
of the sampling method, i.e., rolling shutter or
global shutter. For example, the influence of undesirable ar-
tifacts
caused by non-ideal sampling is disregarded.
•For now, the proposed system only works with grayscale
videos. Multi-channel video frames (e.g., RGB videos) can be
further implemented, as the OCC-KRF algorithm can perform
individually per channel.
## 2

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
This work is segmented into eight sections. In Section2, the
definitions of mathematical notations used in this work are pre-
sented,
along with a brief review of the PARAFAC tensor decom-
position.
In Section3, the proposed system is developed. Section4
describes
how the OOK, PPM, and PWM modulations are compat-
ible
with the proposed scheme. In Section5, the OCC-KRF algo-
rithm
is presented, along with data rate, data volume, and receiver
complexity calculations. In Section6, numerical analysis through
computer simulations is performed to solidify the contributions’
validity. After the conclusion in Section7, the Appendix brings
three design rules in the form of mathematical propositions ded-
icated
to establishing uniqueness and identifiability conditions for
the system model.
- Notations and review on PARAFAC
Scalars, column vectors, matrices, and tensors are denoted by
lower-case (x), boldface lower-case (x), boldface capital (X), and
calligraphic (X)letters, respectively. X
## T
## , X
## ∗
and X
## †
are the trans-
pose,
the conjugate and the pseudoinverse of X, while
## ̂
## Xdenotes
an eventual estimate. The i
## -th
row-vector of Xis given by X
i·
## ,
while and the j
## -th
column of is given by X
## ·j
## . Moreover, 1
## I×J
de-
fines
the I×J
all-ones
matrix, and I
## J
is the identity matrix of
## J×J
size.
The Khatri-Rao product Kof two arbitrary matrices A
## (1)
## ∈C
## I
## 1
## ×R
and A
## (2)
## ∈C
## I
## 2
## ×R
is defined as
## KA
## (1)
## A
## (2)
## ∈C
## I
## 2
## I
## 1
## ×R
## (1)
## =
## [
## A
## (1)
## ·
## 1
## ⊗A
## (2)
## ·
## 1
## A
## (1)
## ·
## 2
## ⊗A
## (2)
## ·
## 2
## ···A
## (1)
## ·
## R
## ⊗A
## (2)
## ·
## R
## ]
## (2)
where ⊗is the Kronecker product. For a I
## 1
## I
## 2
concatenated ar-
ray
index, its element ordering follows the lexicographic order
## (i
## 2
## −1)I
## 1
## +i
## 1
## =1, 2, 3, ···, I
## 1
## I
## 2
, with i
## 1
## =1, 2, ···, I
## 1
and i
## 2
## =
## 1, 2, ···, I
## 2
## .
For a third-order tensor X ∈C
## I×J×K
with a PARAFAC [34]
decomposition
## X =A
## (1)
## , A
## (2)
## , A
## (3)
; R, its mode-1, mode-2 and
mode-3 unfoldings are respectively given by
## X
## (1)
## =
## (
## A
## (3)
## A
## (2)
## )(
## A
## (1)
## )
## T
## (3)
## X
## (2)
## =
## (
## A
## (1)
## A
## (3)
## )(
## A
## (2)
## )
## T
## (4)
## X
## (3)
## =
## (
## A
## (2)
## A
## (1)
## )(
## A
## (3)
## )
## T
## (5)
where Ris the tensor-rank and the number of columns of A
## (1)
## ∈
## C
## I
## 1
## ×R
## , A
## (2)
## ∈C
## I
## 2
## ×R
, and A
## (3)
## ∈C
## I
## 3
## ×R
## .
The powerful essential uniqueness property of the PARAFAC de-
composition
is summarized in Theorem1. Notations and defini-
tions
used in the following theorems follow those defined in the
previous paragraphs of this section.
Theorem 1 ([34]). Given the model X =A
## (1)
## , A
## (2)
## , A
## (3)
; R, then the
property of the essential uniqueness of the PARAFAC decomposition
means that its matrix factors are unique up to column scaling and per-
mutation
ambiguities. In other words, there is a permutation matrix 
and diagonal scaling matrices 
## A
## , 
## B
, and 
## C
such that
## X=
## ˆ
## A
## (1)
## ,
## ˆ
## A
## (2)
## ,
## ˆ
## A
## (3)
## ;R(6)
where
## ˆ
## A
## (1)
## =A
## (1)
## 
## A
## ,
## ˆ
## A
## (2)
## =A
## (2)
## 
## B
## ,
## ˆ
## A
## (3)
## =A
## (3)
## 
## C
## (7)
## 
## A
## 
## B
## 
## C
## =I
## R
## (8)
Sufficient uniqueness conditions are reviewed in the Theo-
rems2,
3, and 4.
Theorem 2 ([38]). Given X =A
## (1)
## , A
## (2)
## , A
## (3)
; R, then this decompo-
sition
is essentially unique if k
## A
## (1)
## +k
## A
## (2)
## +k
## A
## (3)
## ≥2
## R
+2, where k
## A
## (i)
denotes the Kruskal rank of A
## (i)
## .
Theorem 3 ([39,40]). Given X =A
## (1)
## , A
## (2)
## , A
## (3)
; R, let I
## 1
≥R. Then
this decomposition is essentially unique, almost surely, if I
## 2
## (I
## 2
## −
## 1)I
## 3
## (I
## 3
## −1) ≥2
## R
## (R −1).
Theorem 4 ([41–43]). Given X =A
## (1)
## , A
## (2)
## , A
## (3)
; R, let I
## 1
≥Rand
min(I
## 2
## , I
## 3
) ≥3. Then this decomposition is essentially unique, almost
surely, if (I
## 2
## −1)(I
## 3
## −1) ≥R.
- Proposed tensor-based OCC system
In our proposed OCC/S2C system, each pixel of a digital video
of resolution J
pixels
by L
pixels
is modulated by a string of S
symbols.
Each symbol is formed by P
samples
(pulses), such that
## K=SP
is
the number of samples per pixel. In other words, real
baseband symbols stored in the matrix S ∈R
## K×JL
determine the
information to be encoded into JL
pixels.
Let this video comprise a set of F
frames,
and that x
f
## ∈
## R
## JL×1
is a vectorized form of the f
## -th
frame. Video matrix X =
## [
x
## 1
x
## 2
## ···x
## F
## ]
## ∈R
## F×JL
is the rearranged block of digital video in
which it is desired to encode the message contained in S.
The OCC-encoding proposed here is based on the KRST coding
[35], so we have the following coded video for displaying:
## ̄
## X=
## (
## SX
## )
## ∈R
## KF×JL
## (9)
Realize that thanks to the Khatri-Rao operation in (9), the F
frames

of Xare replicated by a Kfactor. In other words, the native en-
coded
video becomes Klengthier than the original one, and then
must be played at a speed Ktimes greater.
For S2C communications, the Direct Current (DC) LOS channel
gain between the n-th IS pixel and the j-th screen pixel is given
by
## W
n,j
## =
## (
m+1)A
2πD
γ
n,j
cos
m
(φ)gT
s
cos(θ
n,j
## )(10)
where D
n,j
=D ∀ {n, j}is the distance between screen and camera,
Ais the area of the camera lens, mis the order of the screen’s
LEDs Lambertian emission, γis the optical path loss coefficient, g
is
the lens gain, T
s
is the signal transmittance of the optical filter,
φis the LEDs irradiance angle, and θ
n,j
is the angle of incidence of
the optical signals on the camera. W
n,j
=0if θ
n,j
falls out of the
Field of View (FoV) of the camera lens.
Unlike VLC, in which the received signals are captured by dis-
crete
photodiodes, and the channel impulse response is usually
represented by a single Line-Of-Sight (LOS) and Non-Light-Of-Sight
(NLOS) components, for S2C technology it is justified to use the
image-based approach to model the communication link [44,45].
The OCC system based on image sensors can indeed be modeled
as a linear time-invariant (LTI) system [36,46]– i.e., all of its Mod-
ulation
Transfer Functions (MTFs) are LTIs [37].
As an LTI system, image degradation may be modeled as G =
h F, where is the bidimensional convolution operator, and his
the kernel matrix that represents the degradation process. Matrices
Fand Gare respectively the undegraded and degraded images. Al-
ternatively,
the spatial convolution can be replaced by the matrix-
vector
product g =Hf, where g =vec
## (
## G
## )
and f =vec
## (
## F
## )
## . Moreover,
as an LTI system, for zero-boundary conditions, the degradation H
## 3

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
Fig. 1.Organization of the captured video frames. The received video is composed
of a block of KFframes, while the constructed tensor Yis defined in (14)from the
entries of the such video. Matrix Yis defined in (11).
is a Block Toeplitz matrix with Toeplitz Blocks (BTTB) built with
the entries of h[47,48].
Consider then that during transmission, the encoded video
## ̄
## Xis
degraded accordingly to the degradation model:
## Y=H
## ̄
## X
## T
## (11)
where Yis the captured video. The degradation matrix Hmay be
given by
## H=BW∈R
## MN×JL
## (12)
where W ∈R
## MN×JL
and B ∈R
## MN×MN
represent respectively the
DC channel matrix and the (optical and/or motion) blurring matrix
[36]. The (n, j)-th element of Wis given in (10).
Combining (9) and (11), the noiseless video Ygenerated by the
Image Sensor (IS) is given by:
## Y=H
## (
## SX
## )
## T
## ∈R
## MN×KF
## (13)
where the rows of Yrepresent the spatial domain (i.e., pixels) and
the columns the time domain (i.e., video frames). In practice, the
acquisition of Yis indeed done by capturing KF
video
frames of
resolution M
by
## N
pixels.
Comparing (13)with the transpose of (3), and making the cor-
respondence

## (
## X
## (1)
## ,A
## (1)
## ,A
## (2)
## ,A
## (3)
## )
## ⇔
## (
## Y
## T
## ,H,X,S
## )
, we can define a
third-order PARAFAC model Y∈R
## MN×F×K
as
## Y=H,X,S,JL(14)
The concept of constructing Yis illustrated in Fig.1. This fig-
ure
indicates the dimensions of the received frames, i.e. matrix or
tensor of received signals.
Assuming the presence of additive noise and interference in the
capturing process, the general system model is given by
## ̃
## Y=Y+N
## (15)
where N∈R
## MN×K×F
is the additive noise tensor, which may
be thermal, shot noise, sampling noises, among others [18]. The
signal-to-noise ratio (SNR) of our OCC system can then be given
by [44]:
## SNR=
## Y
## 2
## F
## N
## 2
## F
## (16)
where Frobenius norm of a tensor is defined in [29].
From (14)the mode-2 and mode-3 unfoldings of Ycan be
given respectively by:
## Y
## (1)
## =
## (
## SX
## )
## H
## T
## ∈C
## FK×MN
## (17)
## Y
## (2)
## =
## (
## XH
## )
## S
## T
## ∈C
## MNF×K
## (18)
## Y
## (3)
## =
## (
## HS
## )
## X
## T
## ∈C
## KMN×F
## (19)
The proposed OCC system is summarized in Fig.2.
Fig. 2.Proposed OCC tensor-based system. The OCC-KRF algorithm can jointly esti-
mate
symbol and video matrices from the received video frames.
Fig. 3.OOK modulation. Bit 1 denotes high-level pulses and Bit 0 the low-level
pulses.
- Pulse modulations
Our proposed OCC transmission scheme is compatible with dif-
ferent
pulse modulations, such as the different variants of Pulse
Position Modulation (PPM), Pulse Amplitude Modulation (PAM),
and Pulse Width Modulation (PWM), since the choice of modu-
lation
changes only the symbol matrix. The discussion presents
the OOK, PWM, and PPM modulations adapted to the proposed
scheme.
The signal patterns of the Undersampling Frequency Shift On-
## Off
Keying (UFSOOK) [22] and Undersampling Phase Shift On-Off
Keying (UPSOOK) [49] modulations could also be emulated with
the structure of S. For these modulations, the Pparameter may
represent an upsampling factor of the transmitted signals.
4.1. On-Off Keying - OOK
The simplest of the modulations used for light communication
is On-Off Keying (OOK). In the OOK modulation, two LED states
represent the two possible symbols. That is, Bit 1 can represent the
non-null pulse, and Bit 0 is the null pulse. Fig.3exemplifies the
OOK modulation for a 2-bit message {10}of Ppulses (the gray and
white colors symbolize high and low-level pulses, respectively.).
For OCC systems, uncoded OOK modulation is typically undesir-
able,
as a long string of zeros can mislead human viewers to think
of dead pixels. Appropriate compensation symbols or Run Length
Limited (RLL) coding schemes can be used to control LED dimming
## [18,50].
## 4

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
Fig. 4.PWM modulation. The symbol defines the duty cycle, i.e., duration ofP
## H
## .
Fig. 5.2-PPM modulation. The message bit denotes where the low-level pulse occurs
within the symbol period of Ppulses.
4.2. Pulse Width Modulation -PWM
In PWM modulation, the symbol determines the duration of the
transmission pulses at high or low levels. The ratio of the time
interval of the high-level pulse (non-zero pulse) to the symbol pe-
riod
is called Duty Cycle. The Duty Cycle (D), according to Fig.4, is
given by:
## D=
## P
## H
## P
## ×100%(20)
where Pis a parameter known to the receiver, and P
## H
is based on
the symbol choice. For example, for P=4, four possible symbols
## {S
## 0
## , S
## 1
## , S
## 2
## , S
## 3
}can be generated using P
## H
## ={P/4, P/2, 3P/4, P},
which would generate duty cycles of 25%, 50%, 75% and 100% re-
spectively.
4.3. Pulse Position Modulation - PPM
In binary Pulse Position modulation (2-PPM), the two possible
symbols within the alphabet are defined by the pulses’ position in
the symbol interval.
In the PPM modulation of Fig.5, the position of the pulse at
a low-level is determined by the bit to be transmitted, while all
the remaining pulses are at a high-level. Here low level means the
pixel light is off, while high level means the pixel is on. For Bit 0,
the low-level pulse occurs at the beginning of the symbol, while
for Bit 1, the low-level pulse occurs at the last pulse. In Fig.5, the
binary message is {01}.
As anyone might suspect, higher-order PPM can easily be im-
plemented
with few adjustments.
In the PPM, it is not possible to control the LED dimming, as
the level of direct current (DC) of the signal is the same for any of
the transmitted symbols. This characteristic is less critical for S2C
systems than for conventional VLC, as ambient lighting is not the
main goal.
- OCC-KRF receiver
In possession of
## ̃
## Y
, a receiver can estimate the symbols in S
while
restoring the video X. This dual task is achieved by the OCC
Khatri-Rao Factorization (OCC-KRF) algorithm, described in Algo-
rithm1.
The OCC-KRF receiver is based on a non-iterative framework,
where degradation matrix Hin (12)must be known a priori. The
OCC-KRF algorithm is based on the Least Squares Khatri-Rao Fac-
torization
(LSKRF) algorithm adapted from [27,28].
Given that His known, then the Khatri-Rao product S Xin
(17)can be estimated by a Least Squares (LS) method (Step 2 in
Algorithm1). The OCC-KRF algorithm then decomposes this prod-
uct
into its two matrix factors (Step 3 in Algorithm1).
In the output of OCC-KRF, the estimated matrices
## ˆ
## Sand
## ˆ
## Xmay
have scaling ambiguities on their columns, as by Proposition1in
the Appendix. Let the correspondence
## (
## A
## (1)
## ,A
## (2)
## ,A
## (3)
## )
## ⇔
## (
## H,X,S
## )
still be valid. Once His known, then H =
## ˆ
H, which means from (7)
that
## 
## A
## = =I
## R
## .
Therefore, there is only an arbitrary diagonal matrix  ∈
## C
## JL×JL
that satisfies (8), i.e.,  ⇔
## C
## =
## −1
## B
and
## X=
## ˆ
## X,S=
## ˆ
## S
## −1
## (21)
Ambiguity is easily avoided if X
## ·f
is known beforehand by the
receiver, as X
## ·f
## =
## ˆ
## X
## ·f
. The ambiguity removal is done in Steps
4 and 5 of Algorithm1. Note in (23) that
## ˆ
## X
## ·f
## (and X
## ·f
) must not
have any zero elements, or else (23)is undefined.
Algorithm 1 OCC-KRF.
## Inputs:
## ̃
## Y
, H, and X
## ·f
## ∀f∈{1, 2, ···, F}
## 1: Organize
## ̃
## Y
into its mode-1 unfolding
## ̃
## Y
## (1)
## ;
2: From (13), do the LS minimization:
## ˆ
## Y=
## ̃
## Y
## (1)
## (
## H
## T
## )
## †
## ≈S X ∈C
## JL×KF
3: For i =1, ···, JL:
i. Take the i-th row of
## ˆ
Y, and rearrange its KFentries to form the rank-one
matrix
## ˆ
## Y
i
## ∈C
## K×F
, such that its (k, f)element, for {k, f} ≥1, corresponds
to the (k −1)F+felement of the original row vector.
ii. Compute the Single Value Decomposition (SVD) of
## ˆ
## Y
i
, i.e.,
## ˆ
## Y
i
## =UDV
## T
## ≈
## ˆ
## S
## T
## ˆ
## X∈C
## K×F
## .
iii. Find the i-th rows of
## ˆ
## Sand
## ˆ
Xfrom the rank-one approximation:
## ˆ
## S
i·
## =U
## T
## ·1
## ,
## ˆ
## X
i·
## =V
## T
## ·1
## (22)
where U
## ·1
and V
## ·1
are respectively the first columns of Uand V. Disregard
the singular values in D.
4: Given an arbitrarily f-th known video frame X
## ·f
, find the ambiguity matrix
from (21):
## ≈
## (
## X
## ·f
## )
## ./
## (
## ˆ
## X
## ·f
## )
## (23)
where operator ./indicates the element-wise division.
5: Remove column ambiguities on
## ˆ
## Sand
## ˆ
## X:
## ˆ
## X←
## ˆ
## X
## −1
## ,
## ˆ
## S←
## ˆ
## S(24)
## Ouputs:
## ˆ
## Xand
## ˆ
## S
5.1. Considerations on frame rate, data volume, and symbol rate
In S2C systems, information symbols are encoded into video
pixels, and then recovered by an optical camera receiver, a priori
without impairing perceived visual quality if the screen’s refresh
rate is greater than 70 Hz [51].
Let r
## S
be the video playback rate, r
## V
the original (native) un-
coded
video frame rate, and r
## C
the capture rate of the IS installed
at the receiver. Due to the KRST coding in (9), r
## S
becomes Ktimes
## 5

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
greater than r
## V
, i.e., the video must be played at r
## S
=Kr
## V
. On the
other hand, by the usual definition, r
## V
## =F/T
frames
per second,
where T
is
the video block duration (in seconds). Finally, consider-
ing
the acquisition by the IS, one can establish the condition
r
## C
## ≥r
## S
## =KF/T(25)
For r
## C
## >r
## S
, the video Yis oversampled at the receiver. It is crucial
to note that low-frequency components may occur in the modu-
lated
signal due to the choice of modulation. Therefore, it is ad-
vised
that the video playback rate be reasonably greater than 70
Hz, e.g., 120 Hz or higher.
For an IS resolution of M×N
pixels,
with b
bits
of quantization,
the total volume of data (in Bytes per second) to be processed by
the receiver is
## V
## T
=(b/8)MNr
c
≥(b/8)MNKF/T(26)
Regarding the symbol rate r
## (symbols
per second), since JL
screen’s
pixels carry S
symbols
each per T
seconds,
then r
is
equal
to
r=JLS/T=JLSr
## V
/F=JLr
## S
## /(FP)(27)
In other words, comparing (26)to (27), increasing F
increases
## V
## T
while reduces r
## .
Realize that r
## S
and r
## V
are dependent variables on
## F/T
## ,
while r
## C
depends only on the camera configuration.
5.2. OCC-KRF computational complexity
The complexity of OCC-KRF is based mainly on the SVD op-
erations
employed in Step 2 and Step 3.ii of Algorithm1. Other
one-time operations, such as single multiplications/divisions and
tensor unfolding, are not taken into account in the total complex-
ity
calculation.
In Step 2, for the SVD-based pseudo-inversion of Hof dimen-
sions
MN×JLwith MN≥JL, its complexity in floating-point
operations O
## {
## .
## }
is approximately [27]:
## O
## LS
## O
## {
## (
## MN)
## 2
## JL
## }
## (28)
In Step 3.ii, there are JLsingular-value decompositions of F×K
matrices.
In this case, the complexity of this step is roughly
## O
## SVD
## O
## {
JL.max(F,K)
## 2
.min(F,K)
## }
## (29)
such that the OCC-KRF’s complexity is O
## KRF
## =O
## LS
## +O
## SVD
## . In
the case of MN=JL, the complexity follows a cubic function of
the camera resolution, although the data volume V
## T
in (26)grows
only linearly with MN. On the other hand, the video resolution JL
appears
in both (28) and (29).
As the number of video pixels is usually greater than the num-
ber
of video frames, evidently the LS process in Step 2 of Algo-
rithm1is
often more cumbersome than the SVD factorization in
Step 3. However, with a time-invariant or very slow fading in (12),
then
## (
## H
## T
## )
## †
can be calculated only once for several transmission
blocks.
## 6. Simulations
In this section, numerical analyses demonstrate the proposed
system’s functionality and predict its behavior in terms of some
of its parameters. Due to the absence of tensor-based works for
Screen-to-Camera communications, the proposed system is com-
pared
to classical matrix-based schemes: in Section6.2, the video
Fig. 6.Symbol and video NMSE for different values of spatial resolution.
restoration performance is contrasted with the classic degrada-
tion
matrix inversion process, while in Section6.3, symbol detec-
tion
performance is measured against the conventional S2C ap-
proach.
In Section6.5the Hidden Asynchronous Quick Link (HA-
## QL)
scheme is compared with our method.
The simulations are done to obtain the Symbol Error Rate (SER),
as well as the video reconstruction error, called here Video Nor-
malized
Mean Square Error (Video NMSE) and given by
Video NMSE=
## E
## {

## X−
## ˆ
## X
## 2
## F
## }
## E
## {

## X
## 2
## F
## }
## (30)
where
## ˆ
Xis estimated by the OCC-KRF receiver. The operator E{.}
means the statistical expectation, and 	.
## 2
## F
indicates the Frobenius
norm. Average values are obtained from 10
## 3
Monte Carlo runs. For
every run, the additive white Gaussian noise power is adjusted to
the proper SNR using (16).
Symbols are generated using the 2-PPM modulation described
in Section4. Only Section6.4addresses the PWM and OOK mod-
ulations.
A total of JLSsymbols are transmitted for each Monte
Carlo run, such that from (27)the symbol rate for simulated videos
of rv =30 fps is r=30(JLS/F)symbols per second – different pa-
rameters
J, L, S, and Fare simulated in this section.
Unless noted otherwise, the degradation matrix is set to H =
## I
## MN
, with JL =MN, which certainly agrees with Proposition1in
the Appendix. This hypothesis assumes that both the camera and
the screen are static (i.e., no motion blur) and that the communica-
tion
distance is short (e.g., no defocus blur, small FoV angle, small
attenuation, and pixel matching between screen and camera).
When synthetic videos are used, the entries of Xare indepen-
dently
drawn from a continuous Uniform distribution U(0, A), with
A =1representing the highest possible pixel intensity.
6.1. Video resolution J×L
Fig.6shows the Symbol NMSE and Video NMSE curves for dif-
ferent
screen resolutions. The Video NMSE is given by (30) and the
Symbol NMSE by
Symbol NMSE=
## E
## {

## S−
## ˆ
## S
## 2
## F
## }
## E
## {

## S
## 2
## F
## }
## .
## (31)
## 6

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
Fig. 7.SER for different values ofPandS.
Indeed, by Fig.6video resolution has no impact on symbol or
video estimation error performances. The fact that the increase in
resolution also increases the number of unknown elements in S
and
Xaccounts for the absent benefit in terms of estimation gain.
On the other hand, these parameters impact the data rate in (27)
and
complexity of the OCC-KRF receiver in (28)-(29), as shown in
## Sections5.1and 5.2.
6.2. Symbol pulses K
Fig.7compares different SER curves for different S
and
## P
val-
ues.
All values of K=SP
agree
with condition (A.3)of Proposi-
tion3(in
the Appendix). Using (27)with J=L =20 pixels and
F=20 frames, the symbol rate in Fig.7is given by r=20
## Sr
## V
## .
Thus, symbol/bit rate ranges from r=500
r
## V
(for S=25) to r=
## 2000
r
## V
(for S=100). For instance, for a video of r
## V
=30 fps, then
the data rate in Fig.7would range from 15 kbps to 60 kbps.
From varying P
## ,
one may note that it brings a coding gain,
mainly at a low SNR regime, whereas increasing Sdoes not. This
insensitivity of SER to the increase in Sis evident from the su-
perposition
of the curves for P=4. It is convenient to verify by
definition that both Sand Pdetermine the size of the matrix S
and
the third dimension of the tensor Y, but only the former in-
creases
the number of symbols to be estimated.
Fig.8brings the curves of video NMSE with the same system
parameters used for Fig.7. In addition, the curves for (S, P) =
## (
100, 16)are displayed. Fig.8also compares the OCC-KRF curves
to the hypothesis of an uncoded video restoration scenario. As un-
coded
video one shall understand (19)with S =1
## 1×JL
, that yields
## Y
## (3)
## =HX
## T
## ∈C
## MN×F
## (32)
which is nothing but the conventional non-OCC video degradation
model. Then, the video NMSE curve for uncoded video estimation
in Fig.8is obtained from the following LS restoration inversion
process
## ˆ
## X=
## (
## H
## †
## ̃
## Y
## (3)
## )
## T
## (33)
which for simulation in Fig.8leads to
## ˆ
## X=
## (
## ̃
## Y
## (3)
## )
## T
in this simula-
tion.
Both Pand Simpact video restoration performance. As K=SP
gives
the number of rows of S, an improvement seen with increas-
ing
Kwas expected, primarily since the video matrix Xdoes not
depend on any of these parameters.
From a communication point of view, having a large Svalue, as
in Fig.7and Fig.8, is justified only by a higher symbol rate. How-
ever,
increasing Sfrom a certain point does not bring benefits in
Fig. 8.Video NMSE for different values ofPandS.
symbol estimation (Fig.7) or significant gains in video estimation
(Fig.8), which can be achieved by raising P
in
both cases. In the
simulated range of Fig.8, doubling P
led
to a consistent 3 dB gain
in SNR, while doubling S
from
50 to 100 for P=4only led to a
marginal and negligible benefit.
When comparing the performance of the OCC-KRF with the
simple inversion of the degradation matrix (i.e., S=P=1), it is
clear that the proposed tensor-coding scheme effectively enhances
the quality of the recovered video. The price to pay is mainly in
the increase in the camera’s capture rate and the volume of data
generated – see (25) and (26).
6.3. Number of frames F
Fig.9compares our proposed tensor-based scheme to a matrix-
based
approach. As conventional OCC matrix-based receivers usu-
ally
estimate symbols on a frame-by-frame basis, if in (18)one has
F=1, then the following equation is obtained:
## ̄
## YHS
## T
## ∈C
## MN×K
## (34)
In other words, the third-order tensor Y∈C
## MN×F×K
is reduced
to the matrix (34). As for the simulations here H =I
## MN
, then sim-
ply

## ̄
## Y=S
## T
. This is consistent with the conventional non-S2C OCC
schemes [1], in which the symbols are directly mapped to the
screen’s pixel intensities at each frame.
Considering from (27) that symbol rate is given by r=JLr
v
α,
where α=S/F, we evaluate here two scenarios: a) only Fis
increased, and then rand αdecrease; and b) Fand Sare in-
creased
proportionally, then both rand αare kept constant. In
both scenarios, J, L, and r
## V
are constant. For α={0.625; 1; 2.5}
the obtained symbol rate would be respectively r={7, 5; 12; 30}
kilobaud (kBd) if rv =30 fps, where one kilobaud represents 1000
symbols per second.
The first thing to note in Fig.9is that Fbrings a diversity gain,
not achieved with Por Sin Fig.7.
As the number of unknowns Sdoes not depend on F, then
the increase of this parameter brought the referred estimation
gain. This behavior was expected, typical of other communication
schemes that use the PARAFAC model. It helps that the entries of X
are
random, of a continuous uniform distribution, then this matrix
naturally has a conditioning number. As the data rate is inversely
proportional to F, a trade-off between diversity gain and data rate
exists, similar to countless other space-time block coding schemes.
Now, when the data rate must be kept constant, the results in
Fig.9indicate that it may be convenient to compensate for the
larger number of frames by increasing the number of symbols per
block of frames. The same diversity gain with Fin Fig.9can be
## 7

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
Fig. 9.SER for different values ofF.
Fig. 10.Video NMSE for different values ofF.
found, but the negative effect of the rate reduction was avoided.
Negatively, the increase in Simpacts both the volume of data gen-
erated
and the complexity of the receiver. In addition, this increase
also requires a proportional increase in the camera’s capture rate
r
## C
, as mentioned in Sections5.1and 5.2.
In terms of NMSE video improvement, now increasing Sis ben-
eficial
while increasing Fhas no effect in Fig.10. While diversity
gains are attributed only to the increase of Fin Fig.9, this pa-
rameter
does not improve the video estimation in Fig.10. On the
other hand, doubling Sbrings about a 3 dB gain in video restora-
tion
performance.
The behaviors in Fig.9and Fig.10were expected, as the num-
ber
of unknown symbols depends on S, while the length of the
unknown video is a function of F. In both Fig.9and Fig.10, the
best estimation scenario occurred when Fand Sincreased propor-
tionally,
keeping αconstant.
6.4. Impact of different pulse modulations in the proposed system
The three modulations presented in Section4serve to demon-
strate
the flexibility of the proposed transmission scheme for dif-
ferent
pulse modulations.
Comparing video restoration performance using the three sug-
gested
modulations, Fig.11demonstrates that PWM and PPM
modulations have similar performance – and are superior to OOK
modulation. Given the hypothesis that the generated and simulated
symbols within an alphabet are equiprobable, there is a greater
presence of zeros in the symbol matrix with the OOK modulation.
This sparsity in Sis likely the culprit for a worse performance of
OOK compared to PWM and PPM.
Fig. 11.Video NMSE for OOK, PWM and PPM.
6.5. Comparison with HA-QL
Perhaps the most similar S2C standardized technology to our
proposal is the HA-QL [1]. In this standard, HA-QL is inserted in the
PHI VI category, intended for use with video displays with low data
rates. Moreover, as its name reveals, HA-QL is based on the A-QL
scheme [1], but modulates the pixel intensity of the original image,
in order to “hide” the frame of encoded pixels from human view.
The comparison in this subsection is simplified: it is assumed
that the region of interest is identified, the display and camera
are aligned, there is no frame rotation and there are no synchro-
nization
issues throughout the transmission. Although both HA-QL
and A-QL have proposed strategies to deal with some of these
challenges, such by the insertion of reference cells and a down-
sampling
process in the receiver, these could also be adapted to
our proposed scheme.
Assuming identically sized frames, the overall coding rate of the
HA-QL scheme is 7/120, since the concatenation of the outer code
Reed-Solomon RS(15,7) with the inner convolutional code CC(1/4)
is suggested by IEEE 802.15.7m – in addition to a 1/2-rate RLL cod-
ing
to generate consecutive modulated and non-modulated frames.
This low coding rate justifies the low data rate attainable by HA-
## QL,
in the order of 140 bps [1].
On the other hand, the coding rate of the proposed scheme,
ignoring the number of pixels in each video frame, is 1/FP. For
instance, by choosing P=4 and F=5, the coding rate is equal to
1/20, slightly smaller than the one suggested for HA-QL.
Fig.12compares the SER of the proposed scheme with the
HA-QL, for the coding rates mentioned in the two previous para-
graphs.
For HA-QL, a hard-decision Viterbi decoder was used at
the receiver, while for the proposed scheme we use the OCC-KRF
algorithm. Note that OCC-KRF does not exploit an error-correcting
coding, but only a space-time coding.
Although HA-QL outperforms the proposed scheme for high
SNR, thanks to the use of concatenated FEC codes, in the opposite
situation, e.g., low SNR with very low screen brightness or large
distance between the screen and camera, the proposed scheme
promises superior performance. Furthermore, the proposed scheme
leaves room for the use of different coding rates, as shown in
Fig.12, as well as the possible combining it with different error-
correcting
codes. And, last but not least, the proposed scheme
allows the restoration of encoded video, which is not foreseen by
## HA-QL.
6.6. Real videos
The performance of the proposed system for real videos was
also verified by numerical analysis. The results and conclusions
## 8

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
Fig. 12.Comparison with HA-QL for different coding rates.
Fig. 13.Real-video restoration with different simulated SNR. (a) uncoded video at
the transmitter side; (b) restored at SNR=0dB; (c) SNR=10 dB; (d) SNR=20 dB;
(e) SNR=30 dB; and (f) SNR=40 dB.
found were very similar to those seen in the last simulation re-
sults.
They are omitted here for the sake of conciseness only.
As an example, Fig.13shows the same indexed video frame, in
different stages of the transmission process and at different SNR
levels. The simulation parameters were P=4pulses per sym-
bol,
S=4 symbols per video block, F=80 frames, J=M=72
pixels,
and L =N=128 pixels. The full video, for different val-
ues
of SNR, is accessed with
https://www.youtube .com /watch ?v =
OuOVaucpV3Q.
Other simulated videos, with different parameters,
can be found in the same Youtube channel.
In terms of symbol error performance, the OCC-KRF algorithm
achieves similar results for various real-world videos tested. Fig.14
depicts
SER curves for widely used benchmark videos.
## 1
## Because
the proposed coding system does not perform any type of com-
pression
or texture-based image processing, the complexity of the
## 1
https://media .xiph .org /video /derf/.
Fig. 14.SER performance for real-world video sequences.
Fig. 15.Impact of the proposed coding scheme to a real-video sequence (“Foreman”
video encoded with 2-PPM modulation and P=8). a) an original video frame; b)
respective coded frame; c) composite video frame; d) restored video frame.
algorithm does not change with the video, and only minor differ-
ences
in symbol estimation are apparently verified, as shown in
Fig.14. Videos with dimensions M=J=176 pixels, N=L =144
pixels,
F=50 frames, P=8pulses per symbol, and S = 100 sym-
bols
per block were used to generate the curves.
In terms of visual quality, Fig.15depicts the effects of encod-
ing
on a real-world video, the ‘Foreman’ video. It includes a frame
from the original video (a), a frame encoded with 2-PPM modu-
lation
(b), a composite figure (c), and the frame restored by the
OCC-KRF algorithm (d). The composite figure, formed by a uni-
formly
weighted summing of P=8 coded frames, is artificially
generated only for the sake of illustrating how the human eye
would likely see the coded frame within the video sequence. The
restored frame is relative to the simulation parameters in Fig.14
for
SNR=20 dB.
The first thing to notice in Fig.15is the presence of many zero
pixels in the coded frame (Fig.15.(b)), due to the low-level pulses
of the 2-PPM modulation. This effect would also appear with the
other intensity-based modulations. On the other hand, increasing
## 9

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
the pulse rate mitigates the flicker, reducing the perception of this
amplitude variation – as Fig.15.(c) intends to illustrate. Finally, the
visual quality is further improved through the video restoration
process by the OCC-KRF algorithm (Fig.15.(d)).
6.7. Overall discussion
The screen resolution is proportional to the maximum achiev-
able
symbol rate at the same time it produces more data to be
processed by the receiver. This conclusion is valid for basically
all OCC systems. However, there are no symbol or video estima-
tion
improvements when increasing this spatial resolution. It is
noteworthy that for now, the screen resolution favors multiplex-
ing
gains over spatial diversity gains, which could be obtained if
a block of pixels could provide redundancy for a single symbol.
Importantly, the cubic-order complexity of OCC-KRF shall not be
neglected for high-resolution screens.
Moreover, increasing symbol pulses K
leads
to estimation gains
in both video reconstruction and symbol estimation. If the number
of S
symbols
per video block is increased, there is a beneficial gain
in terms of symbol rate but a marginal SNR gain on video restora-
tion
and no gain for symbol detection. On the other hand, the
number of pulses per symbol P
brings
SNR gain for both symbol
and video estimation. Besides, a greater P
can
be used for over-
sampling,
providing room for dimming control [18], to improve
synchronization as in [52], or to allow even more flexibility to im-
plement
other pulse modulations.
Finally, the increase in the number of video frames F
per
block
brought gains in video restoration and symbol detection. The draw-
back
is that it also reduces the symbol rate. However, the diversity
gains generated by large F
may
justify the rate reduction, espe-
cially
if image degradation is critical.
## 7. Conclusion
This work presented a new Screen-to-Camera (S2C) Optical
Camera Communication (OCC) scheme. The main novelty is in its
tensor coding, based on the PARAFAC decomposition to model
symbol, video, and image degradation as its matrix factors. This
approach, never used before for OCC or S2C systems, allows the
development of a blind receiver capable of restoring the quality
of the transmitted video while recovering the encoded symbols.
Proposed design rules and numerical analyses allowed us to iden-
tify
system parameters that can dictate performance in different
transmission scenarios. We discussed and weighed the simulation
results in light of other performance metrics, such as the symbol
rate, the volume of data generated, and the computational com-
plexity
of the proposed algorithm.
Interesting perspectives emerge from this work. For instance,
the proposed coding type may be used together with other state-
of-the-art
S2C systems with punctual changes in their framework.
Furthermore, different tensor decompositions in the literature can
be adapted to the same framework to provide even better estima-
tion
performance, more relaxed uniqueness conditions, and lighter
estimation algorithms. In addition, image restoration can be fur-
ther
enhanced if the degradation model can be estimated in the
proposed model.
Lastly, future research should investigate realistic technical el-
ements
of the video capture process, the consequences of frame
synchronization issues, the implementation of color-adapted trans-
mission,
and the effects of region-of-interest identification algo-
rithms.
CRediT authorship contribution statement
Leandro R. Ximenes:Conceptualization, Formal analysis, Inves-
tigation,
## Methodology, Resources, Software, Validation, Visualiza-
tion, Writing – original draft, Writing – review & editing.Bruno A.
Laredo:Conceptualization, Methodology, Software, Writing – orig-
inal
draft.Rangel Arthur:Methodology, Writing – original draft,
Writing – review & editing.
Declaration of competing interest
The authors declare the following financial interests/personal
relationships which may be considered as potential competing in-
terests:
Leandro Ronchini Ximenes reports financial support was pro-
vided
by State University of Campinas (Grant: FAEPEX 2424/23).
Data availability
No data was used for the research described in the article.
Appendix A. Model identifiability
In this section, sufficient conditions are proposed for the pa-
rameters
of our system. Precisely, Proposition1refers to identi-
fiability
conditions for OCC-KRF, whereas the uniqueness of the
PARAFAC decomposition (14), in terms of Theorem1in Section2,
is approached by Proposition2and Proposition3.
Proposition 1. Assume that the degradation matrix His a full-rank ma-
trix.
A sufficient and necessary condition for identifiability of Sand X
using
the OCC-KRF algorithm is that MN≥JL.
Proof.The proof of Proposition1is straightforward. For OCC-KRF
to work as intended, one needs that
## (
## H
## T
## )
## †
be also known, such
that degradation can be mitigated, i.e., H
## T
## (
## H
## T
## )
## †
## =I
## JL
(Step 2 in
Algorithm1). Once His a full-rank matrix by the assumption of
Proposition1, in order that H
## T
## (
## H
## T
## )
## †
## =I
## JL
, the number of rows of
Hmust be greater than its number of columns, i.e., MN≥JL.
Proposition1suggests that using the OCC-KRF algorithm is
linked to a proper resolution of the IS at the receiver. In other
words, the Region Of Interest (ROI) (in pixels) of the captured video
must be at least the size of the screen resolution. Mathematically,
this hypothesis is ordinary if the spatial decimation in the im-
age
degradation model (12)is disregarded. Furthermore, modern
cameras, with resolutions on the order of several Megapixels, can
easily satisfy the conditions of the Proposition in most cases.
Overall, for Proposition1, the hypothesis of the full rank of His
generically true for Linear Time-Invariant (LTI) degradation models.
For LTI systems, His typically a doubly-block Toeplitz (or Circulant)
matrix, built from the elements of an image Kernel (e.g., blurring
mask) [53].
Proposition 2. Assume that His a full-rank matrix, with MN≥JL. Also,
assume that Sand Xare random matrices with full rank and that F
1and JL 1. Under these hypotheses, the essential uniqueness of the
model (14)is almost sure if
## K≥
## ⌈
## 1
## 2
## +
## √
## 2
## JL
## F
## ⌉
## (A.1)
This is a sufficient, but not necessary, condition.
Proof.If one of the matrix factors of (14) has a full column
rank, and other factors are random, then a more relaxed sufficient
uniqueness condition than Kruskal’s condition in Theorem2can be
used. Therefore, from the hypothesis that Hhas a full-column rank,
## 10

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
and that Sand Xare random, Theorem3in Section2with cor-
respondence
## (A
## (1)
## , A
## (2)
## , A
## (3)
## , I
## 1
## , I
## 2
## , I
## 3
## , R) ⇔(H, X, S, MN, F, K, JL)
leads to the following sufficient uniqueness condition
## K(K−1)F(F−1)≥2JL(JL−1)(A.2)
From [40]it may be suggested that (A.2)might be used even if
Sor Hwere not random. Finally, considering the statement that
F1 and JP1, then (A.2) becomes K
## 2
## −K≥2
## (
## JL/F
## )
## 2
, whose
only integer positive solution is given by (A.1), which ends this
proof.
Proposition 3. Assume the hypotheses of Proposition2and that
min
(K, F) ≥3, then the decomposition (14)is essentially unique, al-
most
surely, if
## K≥
## ⌈
## JL
## F
## +1
## ⌉
## (A.3)
Proof.Consider the same correspondence (A
## (1)
## , A
## (2)
## , A
## (3)
## , I
## 1
## , I
## 2
## ,
## I
## 3
,R) ⇔(H, X, S, MN, F, K, JL). Also, let MN≥JL
and
min(F, K)
## ≥
3, as stated. From Theorem4of Section2, a sufficient condition
to guarantee the uniqueness of the PARAFAC model is
## (F−1)(K−1)≥MN(A.4)
As F1by hypothesis stated in Proposition2, then (A.4) becomes
(A.3), ending the proof.
The conditions on K
present
in Proposition2are more relaxed
than those presented in Proposition3. In both cases, screens with
higher resolutions force an increase in the number of frames cap-
tured
by the image sensor.
## References
[1]IEEE standard for local and metropolitan area networks–part 15.7: short-range
optical wireless communications, in: IEEE Std 802.15.7-2018 (Revision of IEEE
Std 802.15.7-2011), 2019, pp. 1–407.
[2] R. Boubezari, H. Le Minh, Z. Ghassemlooy, A. Bouridane, Smartphone cam-
era
based visible light communication, J. Lightwave Technol. 34 (17) (2016)
4121–4127, https://doi .org /10 .1109 /JLT.2016 .2590880.
[3] M.D. Thieu, T.L. Pham, T. Nguyen, Y.M. Jang, Optical-RoI-signaling for vehicular
communications, IEEE Access 7 (2019) 69873–69891, https://doi .org /10 .1109 /
## ACCESS
## .2019 .2918338.
[4] T. Nguyen, A. Islam, Y.M. Jang, Region-of-interest signaling vehicular system
using optical camera communications, IEEE Photonics J. 9(1) (2017) 1–20,
https://doi .org /10 .1109 /JPHOT.2016 .2644960.
[5] Y. Li, Z. Ghassemlooy, X. Tang, B. Lin, Y. Zhang, A VLC smartphone camera
based indoor positioning system, IEEE Photonics Technol. Lett. 30 (13) (2018)
1171–1174, https://doi .org /10 .1109 /LPT.2018 .2834930.
[6] D.T. Nguyen, S. Park, Y. Chae, Y. Park, VLC/OCC hybrid optical wireless systems
for versatile indoor applications, IEEE Access 7 (2019) 22371–22376,
https://
doi
.org /10 .1109 /ACCESS .2019 .2898423.
[7]R.D. Roberts, A MIMO protocol for camera communications (CamCom) using
undersampled frequency shift ON-OFF keying (UFSOOK), in: 2013 IEEE Globe-
com
Workshops (GC Wkshps), 2013, pp. 1052–1057.
[8] N. Saeed, S. Guo, K.-H. Park, T.Y. Al-Naffouri, M.-S. Alouini, Optical camera
communications: survey, use cases, challenges, and future trends, Phys. Com-
mun.
37 (2019) 100900, https://doi .org /10 .1016 /j .phycom .2019 .100900, https://
www.sciencedirect
.com /science /article /pii /S1874490719304859.
[9] Z. Zhang, Y. Xiao, Z. Ma, M. Xiao, Z. Ding, X. Lei, G.K. Karagiannidis, P. Fan,
6G wireless networks: vision, requirements, architecture, and key technologies,
IEEE Veh. Technol. Mag. 14 (3) (2019) 28–41, https://doi .org /10 .1109 /MVT.2019 .
## 2921208.
[10] M.Z. Chowdhury, M. Shahjalal, S. Ahmed, Y.M. Jang, 6G wireless communi-
cation
systems: applications, requirements, technologies, challenges, and re-
search
directions, IEEE Open J. Commun. Soc. 1 (2020) 957–975, https://
doi
.org /10 .1109 /OJCOMS .2020 .3010270.
[11] J. Klein, J. Xu, C. Brauers, J. Jochims, R. Kays, Investigations on temporal sam-
pling
and patternless frame recovery for asynchronous display-camera com-
munication,
IEEE Trans. Circuits Syst. Video Technol. (2021) 1, https://doi .org /
## 10
## .1109 /TCSVT.2021.3106711.
[12]R. Kays, C. Brauers, J. Klein, Modulation concepts for high-rate display-camera
data transmission, in: 2017 IEEE Int. Conf. on Commun. (ICC), 2017, pp. 1–6.
[13] T. Fujihashi, T. Koike-Akino, P.V. Orlik, T. Watanabe, High-throughput visual
MIMO systems for screen-camera communications, IEEE Trans. Mob. Comput.
20 (6) (2021) 2200–2211, https://doi .org /10 .1109 /TMC .2020 .2977042.
[14]Cisco, Cisco annual internet report (2018–2023) white paper, Tech. Rep., March
## 2020.
[15]T. Kasashima, T. Yamazato, H. Okada, T. Fujii, T. Yendo, S. Arai, Interpixel inter-
ference
cancellation method for road-to-vehicle visible light communication,
in: 2013 IEEE 5th International Symposium on Wireless Vehicular Commun.
(WiVeC), 2013, pp. 1–5.
[16] Y. Yang, J. Hao, J. Luo, Ceilingtalk: lightweight indoor broadcast through LED-
camera
communication, IEEE Trans. Mob. Comput. 16 (12) (2017) 3308–3319,
https://doi .org /10 .1109 /TMC .2017.2694834.
[17] D. Vuong, M. Yoo, Interpixel interference mitigation in visible light com-
munication
using image sensor, IEEE Access 6 (2018) 45543–45551,
https://
doi
.org /10 .1109 /ACCESS .2018 .2865492.
[18]Z. Wang, Q. Wang, W. Huang, Z. Xu, Optical Camera Communication: Modula-
tion
and System Design, 2018, pp. 291–351.
[19] T. Nguyen, A. Islam, T. Yamazato, Y.M. Jang, Technical issues on IEEE 802.15.7m
image sensor communication standardization, IEEE Commun. Mag. 56 (2)
(2018) 213–218, https://doi .org /10 .1109 /MCOM .2018 .1700134.
[20] P. Luo, M. Zhang, Z. Ghassemlooy, H. Le Minh, H.-M. Tsai, X. Tang, L.C. Png, D.
Han, Experimental demonstration of RGB LED-based optical camera commu-
nications,
IEEE Photonics J. 7(5) (2015) 1–12, https://doi .org /10 .1109 /JPHOT.
## 2015
## .2486680.
[21] P. Luo, M. Zhang, Z. Ghassemlooy, H. Le Minh, H.-M. Tsai, X. Tang, D. Han,
Experimental demonstration of a 1024-QAM optical camera communication
system, IEEE Photonics Technol. Lett. 28 (2) (2016) 139–142, https://doi .org /
## 10
## .1109 /LPT.2015 .2487544.
[22]R.D. Roberts, Undersampled frequency shift ON-OFF keying (UFSOOK) for cam-
era
communications (CamCom), in: 2013 22nd Wireless and Opt. Commun.
Conf., 2013, pp. 645–648.
[23] A. Wang, Z. Li, C. Peng, G. Shen, G. Fang, B. Zeng, Inframe++: achieve simultane-
ous
screen-human viewing and hidden screen-camera communication, in: Proc.
of the 13th Ann. Int. Conf. on Mobile Systems, Applicat., and Services, MobiSys
’15, Assoc. for Computing Machinery, New York, NY, USA, 2015, pp. 181–195,
https://doi .org /10 .1145 /2742647.2742652.
[24]A. Wang, Z. Li, C. Peng, G. Shen, G. Fang, B. Zeng, Inframe++ achieve simul-
taneous
screen-human viewing and hidden screen-camera communication, in:
Proceedings of the 13th Annual International Conference on Mobile Systems,
Applications, and Services, 2015, pp. 181–195.
[25] K. Zhang, Y. Zhao, C. Wu, C. Yang, K. Huang, C. Peng, Y. Liu, Z. Yang, Chro-
macode:
a fully imperceptible screen-camera communication system, IEEE
Trans. Mob. Comput. 20 (3) (2021) 861–876, https://doi .org /10 .1109 /TMC .2019 .
## 2956493.
[26] H. Fang, D. Chen, F. Wang, Z. Ma, H. Liu, W. Zhou, W. Zhang, N. Yu Tera, Screen-
to-camera
image code with transparency, efficiency, robustness and adaptabil-
ity,
IEEE Trans. Multimed. 24 (2022) 955–967, https://doi .org /10 .1109 /TMM .
## 2021.3061801.
[27] L.R. Ximenes, G. Favier, A.L.F. de Almeida, Closed-form semi-blind receiver for
MIMO relay systems using double Khatri-Rao space-time coding, IEEE Signal
Process. Lett. 23 (3) (2016) 316–320, https://doi .org /10 .1109 /LSP.2016 .2518699.
[28] W.d.C. Freitas, G. Favier, A.L.F. de Almeida, Sequential closed-form semiblind
receiver for space-time coded multihop relaying systems, IEEE Signal Process.
## Lett. 24 (12) (2017) 1773–1777,
https://doi .org /10 .1109 /LSP.2017.2756846.
[29]N.D. Sidiropoulos, L. De Lathauwer, X. Fu, K. Huang, E.E. Papalexakis, C. Falout-
sos,
Tensor decomposition for signal processing and machine learning, IEEE
## Trans. Signal Process. 65 (13) (2017) 3551–3582.
[30]A. Cichocki, Tensor networks for big data analytics and large-scale optimization
problems, CoRR, arXiv:1407.3124.
[31] L. Kuang, F. Hao, L.T. Yang, M. Lin, C. Luo, G. Min, A tensor-based approach for
big data representation and dimensionality reduction, IEEE Trans. Emerg. Topics
Comput. 2(3) (2014) 280–291, https://doi .org /10 .1109 /TETC .2014 .2330516.
[32]L. Kassab, A. Kryshchenko, H. Lyu, D. Molitor, D. Needell, E. Rebrova, On non-
negative
matrix and tensor decompositions for COVID-19 twitter dynamics,
CoRR, arXiv:2010 .01600.
[33] Y.-h. Taguchi, S.A.P. Dharshini, M.M. Gromiha, Identification of transcription fac-
tors,
biological pathways, and diseases as mediated by N6-methyladenosine us-
ing
tensor decomposition-based unsupervised feature extraction, Appl. Sci. 11
(1), https://doi .org /10 .3390 /app11010213, https://www.mdpi .com /2076 -3417 /
## 11
## /1 /213.
[34] R. Harshman, Foundations of the PARAFAC procedure: models and conditions
for an “explanatory” multi-modal factor analysis, UCLA Working Papers in Pho-
netics,
## 16.
[35] N.D. Sidiropoulos, R.S. Budampati, Khatri-Rao space-time codes, IEEE Trans.
Signal Process. 50 (10) (2002) 2396–2407, https://doi .org /10 .1109 /TSP.2002 .
## 803341.
[36] A. Liu, W. Shi, M. Ouyang, W. Liu, Characterization of optical camera communi-
cation
based on a comprehensive system model, J. Lightwave Technol. 40 (18)
(2022) 6087–6100, https://doi .org /10 .1109 /JLT.2022 .3187500.
## 11

L.R. Ximenes, B.A. Laredo and R. ArthurDigital Signal Processing 141 (2023) 104192
[37]Z. Wang, Q. Wang, W. Huang, Z. Xu, Optical Camera Communication: Funda-
mentals,
2018, p. 270.
[38] J.B. Kruskal, Three-way arrays: rank and uniqueness of trilinear decomposi-
tions,
with application to arithmetic complexity and statistics, Linear Alge-
bra
## Appl. 18 (2) (1977) 95–138,
https://doi .org /10 .1016 /0024 -3795(77 )90069 -6,

https://www.sciencedirect .com /science /article /pii /0024379577900696.
[39] L. De Lathauwer, A link between the canonical decomposition in multilinear
algebra and simultaneous matrix diagonalization, SIAM J. Matrix Anal. Appl.
28 (3) (2006) 642–666, https://doi .org /10 .1137 /040608830.
[40] A. Stegeman, On uniqueness conditions for Candecomp/PARAFAC and Indscal
with full column rank in one mode, Linear Algebra Appl. 431 (1) (2009)
211–227, https://doi .org /10 .1016 /j .laa .2009 .02 .025, https://www.sciencedirect .
com
/science /article /pii /S0024379509001104.
[41]L. Chiantini, G. Ottaviani, On generic identifiability of 3-tensors of small rank,
SIAM J. Matrix Anal. Appl. 33 (3) (2012) 1018–1037.
[42] I. Domanov, L.D. Lathauwer, Generic uniqueness conditions for the canonical
polyadic decomposition and INDSCAL, SIAM J. Matrix Anal. Appl. 36 (4) (2015)
1567–1589, https://doi .org /10 .1137 /140970276.
[43] V. Strassen, Rank and optimal computation of generic tensors, Linear Algebra
Appl. 52–53 (1983) 645–685, https://doi .org /10 .1016 /0024 -3795(83 )80041 -X,
https://www.sciencedirect .com /science /article /pii /002437958380041X.
[44] T.L. Pham, M. Shahjalal, V. Bui, Y.M. Jang, Deep learning for optical vehicular
communication, IEEE Access 8 (2020) 102691–102708, https://doi .org /10 .1109 /
## ACCESS
## .2020 .2998944.
## [45] A. Ashok, S. Jain, M. Gruteser, N. Mandayam, W. Yuan, K. Dana, Capac-
ity
of screen-camera communications under perspective distortions, Perva-
sive
Mob. Comput. 16 (2015) 239–250, https://doi .org /10 .1016 /j .pmcj .2014 .
## 11.003,
selected Papers from the Twelfth Annual IEEE International Confer-
ence
on Pervasive Computing and Communications (PerCom 2014), https://
www.sciencedirect
.com /science /article /pii /S1574119214001849.
[46] S. Hranilovic, F. Kschischang, A pixelated MIMO wireless optical communication
system, IEEE J. Sel. Top. Quantum Electron. 12 (4) (2006) 859–874, https://doi .
org
## /10 .1109 /JSTQE .2006 .876601.
[47] Y.W.D. Fan, J.G. Nagy, Synthetic boundary conditions for image deblurring,
Linear Algebra Appl. 434 (11) (2011) 2244–2268, https://doi .org /10 .1016 /j .laa .
## 2009
.12 .021, special issue: Devoted to the 2nd NASC 08 Conference in Nanjing
(NSC), https://www.sciencedirect .com /science /article /pii /S0024379509006545.
[48] M.K. Ng, R.H. Chan, W.-C. Tang, A fast algorithm for deblurring models with
Neumann boundary conditions, SIAM J. Sci. Comput. 21 (3) (1999) 851–866,
https://doi .org /10 .1137 /S1064827598341384.
[49]P. Luo, Z. Ghassemlooy, H. Le Minh, X. Tang, H.-M. Tsai, Undersampled phase
shift ON-OFF keying for camera communication, in: 2014 Sixth Int. Conf. on
Wireless Commun. and Signal Process. (WCSP), 2014, pp. 1–6.
[50] S.H. Lee, S.-Y. Jung, J.K. Kwon, Modulation and coding for dimmable visible light
communication, IEEE Commun. Mag. 53 (2) (2015) 136–143, https://doi .org /10 .
## 1109
## /MCOM .2015 .7045402.
[51]A. Wilkins, J. Veitch, B. Lehman, LED lighting flicker and potential health con-
cerns:
IEEE standard PAR1789 update, in: 2010 IEEE Energy Convers. Congr.
and Expo., 2010, pp. 171–178.
[52]Y. Shiraki, T.G. Sato, Y. Kamamoto, T. Moriya, Flexible synchronization in optical
camera communication with On-Off keying, in: 2017 IEEE Globecom Work-
shops
(GC Wkshps), 2017, pp. 1–6.
[53]A.K. Jain, Fundamentals of Digital Image Processing, Prentice-Hall, Inc., USA,
## 1989.
Leandro R. Ximenesreceived the B.Sc. degree in electrical engineer-
ing
from Federal University of Santa Catarina (UFSC), Florianópolis, Brazil,
in 2009, the M.Sc. degree in teleinformatics engineering from the Fed-
eral
University of Ceará (UFC), Fortaleza, Brazil, in 2011, and the double
Ph.D. degree from the UFC and from the University of Nice, Sophia An-
tipolis,
France, in 2015. Currently he is a tenure-track professor at State
University of Campinas (UNICAMP- Brazil). His research interests are in
the area of signal processing for wireless communications, including vis-
ible
light communications, optical camera communications, cooperative
MIMO communications, blind channel estimation, tensor decompositions,
and adaptive filtering.
Bruno de A. Larêdoreceived a B.Sc. degree in Telecommunications
Engineering from the Estácio de Sá University (UNESA), Rio de Janeiro,
Brazil, in 2014 and an M.Sc. degree in Technology from the University of
Campinas (UNICAMP), Limeira, Brazil, in 2021. He is a Professor at the Fed-
eral
Institute of Science and Technology from São Paulo (IFSP), Campinas,
Brazil. His research interests focus on applying tensor modeling, signal
processing, and video coding to implement new Optical Wireless Com-
munication
techniques based on OCC/S2C frameworks.
Rangel Arthuris an Associate Professor at School of Technology at
University of Campinas (Unicamp), Brazil. He received the Electrical En-
gineering
degree from the State University of Sâo Paulo, Brazil in 1999,
MSc and PhD degrees in Electrical Engineering in 2002 and 2007, respec-
tively,
from University of Campinas, Brazil. He has experience in image
processing, artificial intelligence and embedded systems. He is the author
of several patents in the field of automatic processing of images. Since
2016 he has been an Advisor to the Innovation Agency (Inova) at Uni-
camp.
## 12