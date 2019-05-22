function [ V, t ] = readDSO( channel,reTrig,DSOVisaType,DSOVisaAddress )
%% readDSO.m
%
% Function to read a Digital Storage Oscilloscope using VISA connection
%
% INPUTS:
%       channel             DSO channel to be read
%       reTrig              Single shot the DSO if true, otherwise just
%                           read what ever is currently displayed
%       DSOVisaType         VISA Instrument Type
%                           1       - NI
%                           2       - Agilent
%                           'xxxx'  - User Specified
%                           Default - KEYSIGHT
%       DSOVisaAddress      VISA Instrument Address, default Rigol DS4400
%
% OUTPUTS:
%       V           Read signal
%       t           Time vector for read signal
%
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%% Parameters
READ_TIMEOUT_PERIOD = 20;       % Timeout period for Trigger Read [seconds]

%% Input Check
if ~exist('DSOVisaType','var') 
    % Default DSOVisa type is KEYSIGHT
    DSOVisaType = 'KEYSIGHT';
end
if ~exist('DSOVisaAddress','var') 
    % Default addresss
    DSOVisaAddress = 'USB0::0x1AB1::0x04B1::DS4A194800709::0::INSTR';
end

%% Set Instrument type if variable is numeric
if isnumeric(DSOVisaType)
    switch DSOVisaType
        case 1
            DSOVisaType = 'NI';
        case 2
            DSOVisaType = 'Agilent';
        otherwise
            DSOVisaType = 'KEYSIGHT';
    end
end

%% Interface configuration and DSOVisa connection
% Find a VISA-USB object.
visaObj = instrfind('Type', 'visa-usb', 'RsrcName', DSOVisaAddress, 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(visaObj)
    visaObj = visa(DSOVisaType, DSOVisaAddress);
else
    fclose(visaObj);
    visaObj = visaObj(1);
end

% Set the buffer size
visaObj.InputBufferSize = 2000000;
% Set the timeout value
visaObj.Timeout = 10;
% Set the Byte order
visaObj.ByteOrder = 'littleEndian';
% Open the connection
fopen(visaObj);

%% Setup DSO
% If reTrig flag is set do a Single shot 
if reTrig
    % Make sure the DSO is in run Mode
    fprintf(visaObj,':RUN');
    % Initiate the Single Shot
    fprintf(visaObj,':SINGle');
    % Display update to MATLAB console
    disp('Triggering DSO...');
    % Delay for 2 Seconds to allow for triggering of DSO
    pause(2)
    % Read the status of the DSO
    status = query(visaObj, ':TRIGger:STATus?', '%s\n' ,'%s');
    % Intialize Timeout counter
    tic
    % While the DSO is not stopped
    while ~strcmp('STOP',status)
        % Delay for 1 Second
        pause(1);
        % Re-read the status of the DSO
        status = query(visaObj, ':TRIGger:STATus?', '%s\n' ,'%s');
        
        % If timeout period is reached, exit with error message
        if toc>READ_TIMEOUT_PERIOD
            error('Trigger timeout. Verify Input Signal');
        end
    end
else
    % If reTrig flag is not set, make sure DSO is STOPPED 
    fprintf(visaObj,':STOP');
end

% Specify data from Channel
fprintf(visaObj,[':WAVEFORM:SOURCE CHAN',num2str(channel)]);
disp(['Reading Channel ',num2str(channel)]);
fprintf(visaObj, ':WAV:MODE MAX');
% Specify 5000 points at a time by :WAV:DATA?
fprintf(visaObj,':WAV:POINTS:MODE RAW');
fprintf(visaObj,':WAV:POINTS 1400000');
operationComplete = str2double(query(visaObj,'*OPC?'));
while ~operationComplete
    operationComplete = str2double(query(visaObj,'*OPC?'));
end
% Get the data back as a WORD (i.e., INT16), other options are ASCII and BYTE
fprintf(visaObj,':WAVEFORM:FORMAT WORD');
% Set the byte order on the DSOVisa as well
% fprintf(visaObj,':WAVEFORM:BYTEORDER LSBFirst');
% Get the preamble block
preambleBlock = query(visaObj,':WAVEFORM:PREAMBLE?');

%% Read The Data
% Now send commmand to read data
fprintf(visaObj,':WAV:DATA?');
% read back the BINBLOCK with the data in specified format and store it in
% the waveform structure. FREAD removes the extra terminator in the buffer
waveform.RawData = binblockread(visaObj,'uint16'); fread(visaObj,1);

% Close the VISA connection.
fclose(visaObj);


%% Data processing: Post process the data retreived from the scope
% Maximum value storable in a INT16
maxVal = 2^16;

% split the preambleBlock into individual pieces of info
preambleBlock = regexp(preambleBlock,',','split');

% store all this information into a waveform structure for later use
waveform.Format = str2double(preambleBlock{1});     % This should be 1, since we're specifying INT16 output
waveform.Type = str2double(preambleBlock{2});
waveform.Points = str2double(preambleBlock{3});
waveform.Count = str2double(preambleBlock{4});      % This is always 1
waveform.XIncrement = str2double(preambleBlock{5}); % in seconds
waveform.XOrigin = str2double(preambleBlock{6});    % in seconds
waveform.XReference = str2double(preambleBlock{7});
waveform.YIncrement = str2double(preambleBlock{8}); % V
waveform.YOrigin = str2double(preambleBlock{9});
waveform.YReference = str2double(preambleBlock{10});
waveform.VoltsPerDiv = (maxVal * waveform.YIncrement / 8);      % V
waveform.Offset = ((maxVal/2 - waveform.YReference) * waveform.YIncrement + waveform.YOrigin);         % V
waveform.SecPerDiv = waveform.Points * waveform.XIncrement/10 ; % seconds
waveform.Delay = ((waveform.Points/2 - waveform.XReference) * waveform.XIncrement + waveform.XOrigin); % seconds

% Generate X & Y Data
waveform.XData = (waveform.XIncrement.*(1:length(waveform.RawData))) - waveform.XIncrement;
waveform.YData = (waveform.YIncrement.*(waveform.RawData - waveform.YReference)) + waveform.YOrigin;

%% Save Output Variables
t = waveform.XData;
V = waveform.YData;

%% Delete objects and clear them.
delete(visaObj); clear visaObj;

end

