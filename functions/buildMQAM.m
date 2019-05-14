function [] = buildMQAM(M,Fsym,N_syms,rng_seed,TX_CAL)
% buildMQAM.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems
% Build ARB files for M-QAM system with random data and Tx calibration

addpath('functions\');


sps = 50;           % Samples per Symbol        [Samp/sym]


%% Build Data Block and Modulate
rng(rng_seed);          % Random Seed
dataBlock = randi([0 1],log2(M)*N_syms,1);
modBlock  = qammod(dataBlock,M,'gray','InputType','bit','UnitAveragePower',true);

%% Build Output
Qtx = rectpulse(imag(modBlock),sps);
Itx = rectpulse(real(modBlock),sps);

% Apply Transmitter Calibration Correction
if TX_CAL
    load('Cal Coef Files\txMixerCoefs.mat');     % Mixer calibration parameters
    txCorrected = Ainv*[(Itx-Idc)';(Qtx-Qdc)'];
    Itx = txCorrected(1,:)';
    Qtx = txCorrected(2,:)';
    fname = 'cald';
else
    fname = 'uncal';
end

dirpath = uigetdir('ARB Files','Select Save Location for Rx Cal ARB Files');
if ~dirpath
    dirpath = pwd;
end

% Build AWG Files
Fsamp = sps*Fsym; % Wavegen Sample Rate
writeArbFile([dirpath,'\',num2str(M),'Q_q_',fname],Qtx,Fsamp);
writeArbFile([dirpath,'\',num2str(M),'Q_i_',fname],Itx,Fsamp);
disp('ARB build complete...');
t = length(Itx)/Fsamp;
fprintf('Frame Length: %.3f seconds\n',t)

end

