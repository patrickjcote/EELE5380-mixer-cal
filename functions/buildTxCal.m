function [] = buildTxCal()
% build_TxCal_v1.m
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems
% Build TIMS Tx calibration files

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

%% Try to Write Files To ARB
Vpp = 1;            % ARB Output Peak-Peak Voltage
Fsamp = sps*fb;             % AWG sample rate           [Sa/s]
try
    WRITE_TO_DISK = 0;
    arbTo33500_2channel(Itx,Vpp,'Itx',Qtx,Vpp,'Qtx',Fsamp);
catch
    warning('Failed sending signals to the AWG...');
    WRITE_TO_DISK = 1;
end

%% Write to Thumbdrive
if WRITE_TO_DISK
    questdlg({'The Arbitrary Waveform Generator was not detected.', ...
        'so the waveform files (ARBs) are being built locally.',''...
        'Insert a storage device to save .ARB files','',''}, ...
        'Insert Storage Device', ...
        'Ok','Ok');
    dirpath = uigetdir('ARB Files','Select Save Location for Tx Cal ARB Files');
    if ~dirpath
        error('Build Tx Calibration Files Operation Cancled by User');
    end
    fnameI = [dirpath,'\txCal_I'];
    fnameQ = [dirpath,'\txCal_Q'];
    
    % Build AWG Files
    writeArbFile(fnameI,Itx,Fsamp);
    writeArbFile(fnameQ,Qtx,Fsamp);
    disp('Tx Calibration ARB build complete...');
    t = length(Itx)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end

end

