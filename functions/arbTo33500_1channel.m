function arbTo33500_1channel(arb1,amp1,name1,sRate)
% arbTo33500_1channel.m
% Tyler Holliday
% Adv. Signals & Systems
% April 23, 2019

% Adapted from:
%       arbTo33500.m        by Neil Forcier
%       AgArbTrans_V2.m     by Salaheddin Hosseinzadeh
%
% URL Link:
% https://www.mathworks.com/matlabcentral/fileexchange?q=agilent+33500b

% This function connects to a 33500A/B waveform generator and sends it an
% arbitrary waveform from Matlab via USB. The input arguments are as
% follows:
%   arb1 --> vector of waveform points that is sent to Ch. 1
%   amp1 --> Vpp of Ch. 1 waveform
%   name1 --> name of Ch. 1 waveform
%   sRate --> sample rate of the arb waveform

% Note: this function requires the instrument control toolbox

%% Setup VISA connection
% Find a VISA-USB object.
arbVisa = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x0957::0x2C07::MY52801516::0::INSTR', 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(arbVisa)
    arbVisa = visa('NI', 'USB0::0x0957::0x2C07::MY52801516::0::INSTR');
else
    fclose(arbVisa);
    arbVisa = arbVisa(1);
end

% Set IO timeout
arbVisa.Timeout = 60;       % sec

% calculate output buffer size
buffer = length(arb1)*8;                        % to be used for buffersize
set(arbVisa,'OutputBufferSize',(buffer+125));   % set buffer

%% Initialize 33500 AWG
% open connection to 33500A/B waveform generator
try
    fopen(arbVisa);
catch exception                                 % problem occurred throw error message
    uiwait(msgbox('An error occurred trying to connect to the Waveform Generator','Waveform Generator Error','error'));
    rethrow(exception);
end

% Query Idendity string and report
fprintf (arbVisa, '*IDN?');                     % save USB address as string   
idn = fscanf (arbVisa);
fprintf (idn)
fprintf ('\n\n')

% create waitbar for sending waveform to 33500
mes = ['Connected to ' idn ' sending waveform.....'];
h = waitbar(0,mes);

% Reset instrument
fprintf(arbVisa,'*RST');

%% send waveform to Ch 1 of 33500
% make sure waveform data is in column vector
if isrow(arb1) == 0
    arb1 = arb1';
end

% set the waveform data to single precision
arb1 = single(arb1);

% scale data between 1 and -1
mx = max(abs(arb1));
arb1 = (1*arb1)/mx;

% update waitbar
waitbar(0.1,h,mes);

% configure memory
fprintf(arbVisa,'SOURce1:DATA:VOLatile:CLEar');     % Clear volatile memory
fprintf(arbVisa,'FORM:BORD SWAP');                  % configure the box to correctly accept the binary arb points
arbBytes=num2str(length(arb1)*4);                   % # of bytes

% generate header
header = ['SOURce1:DATA:ARBitrary ' name1 ', #',num2str(length(arbBytes)),arbBytes];
binblockBytes = typecast(arb1,'uint8');             % convert datapoints to binary before sending
fwrite(arbVisa,[header binblockBytes],'uint8');     % combine header and datapoints then send to instrument
fprintf(arbVisa,'*WAI');                            % Make sure no other commands are exectued until arb is done downloadin

% update waitbar
waitbar(0.8,h,mes);

% set ARB name
command = ['SOURce1:FUNCtion:ARBitrary ' name1];    % create name to display on ARB
fprintf(arbVisa,command);                           % set current arb waveform to defined arb testrise

% store waveform in non-volatile memory
% command = ['MMEMory:STOR:DATA1 "INT:\' name1 '.arb"'];      % internal memory
command = ['MMEMory:STOR:DATA1 "USB:\' name1 '.arb"'];      % external USB drive
fprintf(arbVisa,command);

% update waitbar
waitbar(0.9,h,mes);

% set sample rate
command = ['SOURCE1:FUNCtion:ARB:SRATe +' num2str(sRate)]; % create sample rate command
fprintf(arbVisa,command);

% select ARB mode
fprintf(arbVisa,'SOURce1:FUNCtion ARB');            % turn on arb function

% set amplitude, Vpp
command = ['SOURCE1:VOLT ' num2str(amp1)];          % create amplitude, Vpp
fprintf(arbVisa,command);                           % send amplitude command

% set offset
fprintf(arbVisa,'SOURCE1:VOLT:OFFSET 0');           % set offset to 0 V

% enable Ch 1
fprintf(arbVisa,'OUTPUT1 ON');

% set filter type
fprintf(arbVisa,'SOURCE1:FUNCtion:ARB:FILT OFF');	% disable filter

% confirm upload
fprintf('Arb waveform downloaded to channel 1\n\n') % display confirmation in command window

% close message box
waitbar(1,h,mes);
close(h);

% Read Error
fprintf(arbVisa,'SYST:ERR?');                       % query ARB for error report
errorstr = fscanf(arbVisa);                         % save report as string

% error checking
if strncmp (errorstr, '+0,"No error"',13)           % no error detected
    errorcheck = 'Arbitrary waveform generated on Ch. 1 without any error\n\n';
    fprintf (errorcheck)
else                                                % error detected
    errorcheck = ['Error reported (Ch. 1): ', errorstr];
    fprintf (errorcheck)
end


%% close function call
fclose(arbVisa);

end