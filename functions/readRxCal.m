% readRxCal.m
% 2019 - Patrick Cote
% EELE 5380 - Adv Signals
% Calculate Rx calibration matrix from USB or LSB tone
%   test correction with ideal upconversion

close all; clc;
	addpath('functions\');

%% Input Parameters
disp('Reading Rx Calibration...');

% Baseband Freq
prompt = {'Enter Baseband Tone Frequency in Hz:'};
title = 'Input';
dims = [1 35];
definput = {'1000'};
answer = inputdlg(prompt,title,dims,definput);
if isempty(answer)
    fb = 1e3;
else
    fb = str2num(answer{1});
end
if isempty(fb)
    fb = 1e3;       % Symbol Rate
end
fprintf('\nBaseband Frequency set to: %d Hz\n\n',fb);


answer = questdlg('Which RF Sideband? ', ...
    'RF Tone Build', ...
    'LSB','USB','LSB');
% Handle response
switch answer
    case 'LSB'
        LSB = 1;
    case 'USB'
        LSB = 0;
end


%% Read DSO and Calc IQ Correction Matrix
% % Read in data
if exist('SIM_MODE','var')
    if SIM_MODE
        disp('simmode');
        READ_DSO = 0;
    else
        READ_DSO = 1;
    end
    
else
    answer = questdlg('Data Source: ', ...
        'Data Source', ...
        'Read DSO','Load .mat File','Read DSO');
    % Handle response
    switch answer
        case 'Read DSO'
            READ_DSO = 1;
            if LSB
                questdlg('Recall state: "STATE_LSB_RX_CAL.sta" on the AWG',...
                    'Rx LSB Cal', ...
                    'Ok','Ok');
            else
                questdlg('Recall state: "STATE_USB_RX_CAL.sta" on the AWG',...
                    'Rx USB Cal', ...
                    'Ok','Ok');
            end
        case 'Load .mat File'
            READ_DSO = 0;
    end
end

if READ_DSO
    setRigol_rxCal
    pause(2)
    [ Irx, ~ ] = readRigol(1,1,1);
    [ Qrx, tq ] = readRigol(2,0,1);
    % Save
    save(['functions\rxCal_SB',num2str(LSB),'.mat'],'Irx','Qrx','tq');
else
    if isfile(['functions\rxCal_SB',num2str(LSB),'_sim.mat'])
        load(['functions\rxCal_SB',num2str(LSB),'_sim.mat']);
    else
        [file,path] = uigetfile('*.mat');
        load([path,file])
    end
end

fs = 1/mean(diff(tq));

%% LPF Filter
N = 1000;
b = fir1(N,fb/(fs/2));
a = 1;
Irxf = filter(b,a,Irx);
Qrxf = filter(b,a,Qrx);
clear Irx Qrx Irx1 Qrx1
Irx = Irxf(N:end);
Qrx = Qrxf(N:end);
clear Irxf Qrxf

%% AGC
s = Irx + 1i*Qrx; s = s/mean(abs(s));
Irx = real(s); Qrx = imag(s);

%% Save Uncorrected
Irx_raw = Irx;
Qrx_raw = Qrx;

%% Determine Samples per Cycle and Total Periods Received
spc = round(fs/fb);
NT = floor(length(Irx)/spc);

disp('----- Correction Parameters -----');
%% DC Offsect
% Calculate average of N periods
Idc = mean(Irx(1:spc*NT-1))
Qdc = mean(Qrx(1:spc*NT-1))
% Remove DC Offset
Irx = Irx - Idc;
Qrx = Qrx - Qdc;

%% Gain Offset
alpha = rms(Irx)/rms(Qrx)

%% Phase Offset
if LSB % Lower Side Band -> I=cos, Q=sin, I should lag by 90 deg
    phi = wrapTo180(90 + phdiffmeasure(Irx,Qrx)*180/pi)
else   % Upper Side Band -> Q=cos, I=sin, I should lead by 90 deg
    phi = wrapTo180(90 - phdiffmeasure(Irx,Qrx)*180/pi)
end

%% Build Correction Matrix and Save Coefs
A = 1/alpha;
B = 0;
C = -sind(phi)/(alpha*cosd(phi));
D = 1/cosd(phi);

Ainv = [A B;C D];

save('functions\Parameter Files\rxMixerCoefs.mat','Ainv','Idc','Qdc')

%% Test Correction Matrix
% Apply Correction
disp('---- Test Correction Matrix -----');
rxCorrected = Ainv*[(Irx_raw-Idc)';(Qrx_raw-Qdc)'];
Irx = rxCorrected(1,:)';
Qrx = rxCorrected(2,:)';

%% AGC
s = Irx + 1i*Qrx; s = s/mean(abs(s));
Irx = real(s); Qrx = imag(s);

% Corrected Stats
alpha = rms(Irx)/rms(Qrx)
phaseDiff = wrapTo180(phdiffmeasure(Irx,Qrx)*180/pi)
Idc = mean(Irx)
Qdc = mean(Qrx)

% Plot
figure;
plot(Irx_raw,Qrx_raw,'.',Irx,Qrx,'.');
pbaspect([1 1 1]);
grid on; grid minor;
axis([ -1.5 1.5 -1.5 1.5])
legend('Rx','Corrected')


%% ------ Upconvert Test ------
%% Build Time Vec and Ideal 100kHz Upconverting LOs
t = (0:length(Irx_raw)-1)'/fs;
ilo = cos(2*pi*100e3*t);
qlo = sin(2*pi*100e3*t);

%% Upconvert Uncorrected
RFrx = Irx_raw.*ilo + Qrx_raw.*qlo;

%% Load and Apply Correction
load('functions\Parameter Files\rxMixerCoefs.mat');
rxCorrected = Ainv*[(Irx_raw-Idc)';(Qrx_raw-Qdc)'];
Irx = rxCorrected(1,:)';
Qrx = rxCorrected(2,:)';

%% Upconvert Corrected
RFcomp = Irx.*ilo +  Qrx.*qlo;

%% Plot FFTs
fftPlot(RFrx,fs,[90e3 110e3]);
clear title
title('Uncalibrated');
ylim([-85 0]);
fftPlot(RFcomp,fs,[90e3 110e3]);
clear title
title('Calibrated');
ylim([-85 0]);
