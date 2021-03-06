function [SNR, BER, errs] = readMQAM(M,Fsym,N_syms,rng_seed,RX_CAL,VISAtype,VISAaddr)
% read_MQAM.m
% 2019 - Patrick Cote
% EELE 5380 - Adv Signals
% Read in M-QAM sequence with random data


global SIM_MODE
if isempty(SIM_MODE)
    SIM_MODE = 0;
end

%% Read DSO and Calc IQ Correction Matrix
% % Read in data
if ~SIM_MODE
%     answer = questdlg('Data Source: ', ...
%         'Data Source', ...
%         'Read DSO','Load .mat File','Read DSO');
%     % Handle response
%     switch answer
%         case 'Read DSO'
%             READ_DSO = 1;
%         case 'Load .mat File'
%             READ_DSO = 0;
%     end

    READ_DSO = 1;
else
    READ_DSO = 0;
end
    
if READ_DSO
    
    %% Check for VISA Address and Type, if none, set defaults
    if ~exist('VISAaddr','var')
        disp('Setting default DSO address');
        VISAaddr = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR';
    end

    if ~exist('VISAtype','var')
        disp('Setting default DSO type');
        VISAtype = 'KEYSIGHT';
    end

    setDSO(1,Fsym,N_syms,VISAtype,VISAaddr);
    [ Irx, ~ ] = readDSO(1,1,VISAtype,VISAaddr);
    [ Qrx, tq ] = readDSO(2,0,VISAtype,VISAaddr);
    % Save
    save(['Data Files\rxMqam_',num2str(M),'.mat'],'Irx','Qrx','tq');
else
    [file,path] = uigetfile('*.mat');
    load([path,file])
end

%% Rx Calibration Matrix
if RX_CAL
    load('Calibration Files\rxMixerCoefs.mat');
    rxCor = Ainv*[(Irx-Idc)';(Qrx-Qdc)'];
    Irx = rxCor(1,:)'; Qrx = rxCor(2,:)';
end

%% AGC To Unity Power
agc = mean(abs(Irx+1i*Qrx));
Irx = Irx/agc;
Qrx = Qrx/agc;
%% Matched Filter - Averaging FIR
fs = 1/mean(diff(tq));                      % Sample Rate
Rxsps = round(fs/Fsym);                     % Samples per symbol
K = 0.8;                                % Filter Tune
b = 1/Rxsps*K*ones(Rxsps*K,1);          % Filter Taps
Irx = filter(b,1,Irx);
Qrx = filter(b,1,Qrx);

%% Frame Sync
% Build Sync Syms
rng(rng_seed);          % Random Seed
dataTx = randi([0 1],log2(M)*N_syms,1);
syncSyms  = qammod(dataTx,M,'gray','InputType','bit','UnitAveragePower',true,'PlotConstellation',false);
% Synchronize
[symsRx, sto, lag] = frameSync(Irx,Qrx,syncSyms,Rxsps,length(syncSyms));

%% AGC
symsRx = symsRx/mean(abs(symsRx)) * mean(abs(syncSyms));

%% DC Offset
Idc = mean(real(symsRx))-mean(real(syncSyms));
Qdc = mean(imag(symsRx))-mean(imag(syncSyms));
symsRx = symsRx - Idc - 1i*Qdc;

%% Phase Offset Correction
% Calculate phase offset
phaseOFF = (angle(symsRx) - angle(syncSyms))*180/pi;
phaseOffset = mean(wrapTo180(phaseOFF));
% Derotate symbols
symsRx = symsRx.*exp(-1i*phaseOffset*pi/180);

%% SNR Calc
noiseRx = symsRx - syncSyms;
SNR = 10*log10(mean(abs(syncSyms).^2)/mean(abs(noiseRx).^2))

%% Demod
dataRx = qamdemod(symsRx,M,'gray','OutputType','bit','UnitAveragePower',true);

%% Error Calc
errs = sum(dataRx ~= dataTx)
BER = errs/length(dataRx)

%% Plot
figure;
errs = dataRx ~= dataTx;
ndx = ceil(find(errs==1)/log2(M));
plot(real(symsRx),imag(symsRx),'.',real(symsRx(ndx)),imag(symsRx(ndx)),'r.')
pbaspect([1 1 1]);
axis([-1.5 1.5 -1.5 1.5]);
xlabel('I');ylabel('Q');
title('Received Constellation');
grid on; grid minor;


end

