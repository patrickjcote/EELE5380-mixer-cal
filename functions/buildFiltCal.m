function [] = buildFiltCal()


%% Build Pulse
% Parameters
pulse_width = 10e-6;    % Pulse Width           [s]
duty = 1;               % Percent Duty Cycle    [%]
sps = 10;               % Oversample factor     [n]
% Calcs
Fsamp = round(sps/pulse_width); % Wavegen Sample Rate
N = pulse_width*Fsamp;          % Samples Per Pulse
% Built pulse Vector
Itx = zeros(N/(duty/100),1);
Itx(N:N+N-1) = ones(N,1);

%% Try to Write Files To ARB
Vpp = 1;    % ARB Output Peak-Peak Voltage
try
    WRITE_TO_DISK = 0;
    arbTo33500_1channel(Itx,Vpp,'Itx',Fsamp,0);
catch
    warning('Failed sending signal to the AWG...');
    WRITE_TO_DISK = 1;
end


%% Write to Thumbdrive
if WRITE_TO_DISK
    
        questdlg({'The Arbitrary Waveform Generator was not detected.', ...
        'so the waveform files (ARBs) are being built locally.',''...
        'Insert a storage device to save .ARB files','',''}, ...
        'Insert Storage Device', ...
        'Ok','Ok');

    dirpath = uigetdir('ARB Files','Select Save Location for Fitler Cal ARB Files');
    if ~dirpath
        error('Build Fitler Calibration Files Operation Cancled by User');
    end
        fnameI = [dirpath,'\filtCalImpulse'];
    % Build AWG Files
    writeArbFile(fnameI,Itxp,Fsamp);
    disp('Fitler Calibration ARB build complete...');
    t = length(Itxp)/Fsamp;
    fprintf('Frame Length: %.3f seconds\n',t)
end



end

