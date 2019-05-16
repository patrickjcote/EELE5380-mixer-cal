
clear;
clc;
%% Adapters Check
visainfo = instrhwinfo('visa');
if isempty(visainfo.InstalledAdaptors)
    error('No VISA Adapters found... Install a compatible VISA Driver');
end

%% Check Agilent 
% Keysight I/O Driver shows compatibility for both Keysight and agilent so
% to prevent multiple access attempts, remove Agilent from the list
visainfo.InstalledAdaptors(strncmpi(visainfo.InstalledAdaptors,'agilent',7)) = [];

%% Reset Instrument Objects
instrreset;     % clear all open objects

%% Count Total Potential Instruments Found
deviceCount = 0;
for n = 1:length(visainfo.InstalledAdaptors)
    visa_device = instrhwinfo('visa',visainfo.InstalledAdaptors{n});
    if ( isempty(visa_device.ObjectConstructorName) )
        disp({'No VISA instrument is found using',visainfo.InstalledAdaptors{n}});
    else
        for ndx = 1:length(visa_device.ObjectConstructorName)
            deviceCount = deviceCount+1;
        end
    end
end

%% Try to Connect to Detected Devices
% Initialize Device Ndx
ndx = 1;
% For each Installed Adaptor
for n = length(visainfo.InstalledAdaptors)
    visaDriver = instrhwinfo('visa',visainfo.InstalledAdaptors{n});
    if ( isempty(visaDriver.ObjectConstructorName) )
        fprintf('No VISA instrument is found');
    else
        for k = 1:length(visaDriver.ObjectConstructorName)
            % Load VISA object
            VISAobj = eval(visaDriver.ObjectConstructorName{k});      
            try
                % Try connecting to the device
                fopen(VISAobj);
                % If connection success, save info in devices{} struct
                devices{ndx}.VISAobj = VISAobj;
                devices{ndx}.ID = query(devices{k}.VISAobj, '*IDN?');
                devices{ndx}.Instrument = get(devices{k}.VISAobj, 'RsrcName');
                fprintf('Found: %s\n', devices{ndx}.ID);
                ndx = ndx + 1;
            catch
            end
        end
    end
end

if ~(ndx-1)
    disp('No devices found.');
end

%% Reset Instrument Objects
instrreset;     % clear all open objects