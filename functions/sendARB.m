function sendARB(x,Vpp,Fs,filtFlag,instrumentType,intrumentAddress)
% sendARB.m


%% Input Check

% Check Signal Size
xSize = size(x);
if xSize(2) < 2
    Nx = 1; % Only one signal to send
    bufferSize = length(x)*8;      % to be used for buffersize
else
    Nx = 2; % Two signals to send
    bufferSize = max(length(x(:,1)),length(x(:,2)))*8;      % to be used for buffersize
    if length(Vpp)==1
        Vpp = [Vpp Vpp];
    end
    if length(Fs)==1
        Fs = [Fs Fs];
    end
    if length(filtFlag)==1
        filtFlag = [filtFlag filtFlag];
    end
end

%% Instrument Type
% Default to Keysight 33500 awg
if ~exist('instrumentType','var')
    % Default instrument type is KEYSIGHT
    instrumentType = 'KEYSIGHT';
end
if ~exist('intrumentAddress','var')
    % Default addresss
    intrumentAddress = 'USB0::0x0957::0x2C07::MY52801516::0::INSTR';
end

% Set Instrument type if variable is numeric
if isnumeric(instrumentType)
    switch instrumentType
        case 1
            instrumentType = 'NI';
        case 2
            instrumentType = 'Agilent';
        otherwise
            instrumentType = 'KEYSIGHT';
    end
end

%% Setup VISA connection
% Find a VISA-USB object.
visaObj = instrfind('Type', 'visa-usb', 'RsrcName', intrumentAddress, 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(visaObj)
    visaObj = visa(instrumentType, intrumentAddress);
else
    fclose(visaObj);
    visaObj = visaObj(1);
end

% Set VISA Params
visaObj.Timeout = 2;                                % Set timeout [sec]
set(visaObj,'OutputBufferSize',(bufferSize+125));   % set buffer size

% Try to open visa
try
    fopen(visaObj);
catch exception                                 % problem occurred throw error message
    uiwait(msgbox('An error occurred trying to connect to the Waveform Generator','Waveform Generator Error','error'));
    rethrow(exception);
end

% Query Idendity string and report
fprintf (visaObj, '*IDN?');                     % save USB address as string
idn = fscanf (visaObj);
fprintf (idn)
fprintf ('\n\n')

% create waitbar for sending waveform to 33500
mes = ['Connected to ' idn ' sending waveforms.....'];
h = waitbar(0,mes);

% Reset instrument
fprintf(visaObj,'*RST');


%% Send waveform(s)
% For each waveform
for n = 1:Nx
    
    % Set channel
    if (Nx==1 && length(Vpp)==2)
        chnl = 'SOURce2';
        chnlNdx = 2;
    else
        chnl = ['SOURce',num2str(n)];
        chnlNdx = n;
    end
    
    % Load signal to send
    signal = x(:,n)';
    
    % Set the waveform data to single precision
    signal = single(signal);
    
    % Scale data between 1 and -1
    mx = max(abs(signal));
    signal = (1*signal)/mx;
    
    % Update waitbar
    waitbar(0.1,h,mes);
    
    % configure memory
    fprintf(visaObj,[chnl,':DATA:VOLatile:CLEar']);     % Clear volatile memory
    fprintf(visaObj,'FORM:BORD SWAP');                  % configure the box to correctly accept the binary arb points
    arbBytes=num2str(length(signal)*4);                   % # of bytes
    
    % generate header
    header = [chnl,':DATA:ARBitrary ' name1 ', #', num2str(length(arbBytes)), arbBytes];
    binblockBytes = typecast(signal,'uint8');             % convert datapoints to binary before sending
    fwrite(visaObj,[header binblockBytes],'uint8');     % combine header and datapoints then send to instrument
    fprintf(visaObj,'*WAI');                            % Make sure no other commands are exectued until arb is done downloadin
    
    % update waitbar
    waitbar(0.8/Nx,h,mes);
    
    % set ARB name
    command = [chnl,':FUNCtion:ARBitrary ARB', num2str(n)];    % create name command
    fprintf(visaObj,command);                           % set current arb waveform to defined arb testrise

    % update waitbar
    waitbar(0.9/Nx,h,mes);
    
    % set sample rate
    command = [chnl,':FUNCtion:ARB:SRATe +' num2str(Fs(n))]; % create sample rate command
    fprintf(visaObj,command);
    
    % select ARB mode
    fprintf(visaObj,[chnl,':FUNCtion ARB']);        % turn on arb function
    
    % set amplitude, Vpp
    command = [chnl,':VOLT ' num2str(V(n))];      % create amplitude command
    fprintf(visaObj,command);                       % send amplitude command
    
    % set offset
    fprintf(visaObj,[chnl,':VOLT:OFFSET 0']);      % set offset to 0 V
    
    % confirm upload
    disp(['Arb waveform downloaded to Channel ',num2str(chnlNdx)])   % display confirmation in command window
    
    % Read Error
    fprintf(visaObj, 'SYST:ERR?');                      % query ARB for error report
    errorstr = fscanf (visaObj);                        % save report as string
    
    % error checking
    if strncmp (errorstr, '+0,"No error"',13)           % no error detected
        errorcheck = ['Arbitrary waveform generated on Ch. ',num2str(chnlNdx),' without any error\n\n'];
        fprintf (errorcheck)
    else                                                % error detected
        errorcheck = ['Error reported (Ch. ',num2str(chnlNdx),'): ', errorstr];
        fprintf (errorcheck)
    end
    
    switch filtFlag
        % set filter type
        case 0
            fprintf(visaObj,[chnl,':FUNCtion:ARB:FILT OFF']);	% disable filter
        case 1
            fprintf(visaObj,[chnl,':FUNCtion:ARB:FILT NORMal']);
        case 2
            fprintf(visaObj,[chnl,':FUNCtion:ARB:FILT STEP']);
        otherwise
    end

    % enable CHannel
    fprintf(visaObj,['OUTPUT',num2str(chnlNdx),' ON']);
    

    % Delay between setting up channels
    % update waitbar
    waitbar(0.95/Nx,h,mes);
    fprintf(visaObj,'*WAI');

end
%%
    
%% If multipleSync arbs
fprintf(visaObj,'FUNC:ARB:SYNC');

%% Clean Up
close(h);
fclose(visaObj);

end
