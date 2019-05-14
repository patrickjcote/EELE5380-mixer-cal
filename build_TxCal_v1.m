% build_TxCal_v1.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems
% Build TIMS Tx calibration files

format compact; clear; close all; clc;
addpath('functions\');

%% Parameters
% AWG Parameters
fb = 5e3;               % Baseband Signal frequency          [Hz]
sps = 10;               % Samples per symbol
% M-Seq Paramters
N = 10;                 % Number of shift registers
Itaps = [10 9 5 2];     % Feedback Taps for I seq
Qtaps = [10 9 7 6];     % Feedback Taps for Q seq

%% Build Tx Cal Signal
% Orthogonal M-sequences in the I and Q
Iseq = mSeq(N, Itaps)*2-1;
Qseq = mSeq(N, Qtaps)*2-1;
% Scale and Rotate QPSK Constellation
syncSyms = (Iseq +1i*Qseq)/sqrt(2);
syncSyms = syncSyms.*exp(1i*pi/4);
% Rectangular Pulse Shape
Itx = rectpulse(real(syncSyms),sps);
Qtx = rectpulse(imag(syncSyms),sps);

%% BUILD AWG FILES
Fsamp = sps*fb;             % AWG sample rate           [Sa/s]
writeArbFile('Arb Files\txCal_I',Itx,Fsamp);
writeArbFile('Arb Files\txCal_Q',Qtx,Fsamp);
disp('ARB build complete...');
t = length(Itx)/Fsamp;
fprintf('Frame Length: %.3f seconds\n',t)

