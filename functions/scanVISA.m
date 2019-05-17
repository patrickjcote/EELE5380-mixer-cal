function [devices] = scanVISA()
%% scanVISA.m
% Scan for VISA devices
%
% INPUTS:
%       none
% OUTPUT:
%       devices         struct containing device information
%       devices.IDN     Device Name returned from *IDN? query
%       devices.type    Driver type ('keysight','ni','tek',...)
%       devices.addr    Device address, ie. USB0::0x0957::0x2C07::MY52801516::0::INSTR
%  
% 2019 - Patrick Cote
% EELE 5380 - Adv. Signals and Systems

%% Adapters Check
visainfo = instrhwinfo('visa');
if isempty(visainfo.InstalledAdaptors)
    error('No VISA Adapters found. Install a compatible VISA Driver. "Keysight I/O Support Package" can be found in MATLAB Add-Ons');
end

%% Check Agilent 
% Keysight I/O Driver shows compatibility for both Keysight and agilent so
% to prevent multiple access attempts, remove Agilent from the list of
% possible adaptors
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
        for deviceNdx = 1:length(visa_device.ObjectConstructorName)
            deviceCount = deviceCount+1;
        end
    end
end

%% Try to Connect to Detected Devices
% Initialize Device Ndx
deviceNdx = 0;
% For each Installed Adaptor
for n = length(visainfo.InstalledAdaptors)
    % Load the nth Adaptor type
    visaDriver = instrhwinfo('visa',visainfo.InstalledAdaptors{n});
    % If the Constructor Object is not empty
    if ~isempty(visaDriver.ObjectConstructorName)
        % For each Constructor Object in nth adaptor
        for k = 1:length(visaDriver.ObjectConstructorName)
            % Load the kth VISA object
            VISAobj = eval(visaDriver.ObjectConstructorName{k});      
            try
                % Try connecting to the device
                fopen(VISAobj);
                % If connection success, increment the device index
                deviceNdx = deviceNdx + 1;
                % Save info in devices{} struct
                devices{deviceNdx}.IDN  = query(VISAobj, '*IDN?');
                devices{deviceNdx}.addr = get(VISAobj, 'RsrcName');
                devices{deviceNDX}.type = visainfo.InstalledAdaptors{n};
                disp(['Found: ', devices{deviceNdx}.IDN]);
            catch
                % If the device is not connected or if it has already been
                % accessed the "fopen(VISAobj)" will throw an error.  
                % Catch the error and continue the loop
                continue;
            end
        end
    end
end

%% If no Devices Found
if ~(deviceNdx)
    % Warn that no VISA Devices were found
    warning('No VISA devices found...');
    % Set the
    devices = 0;
end

%% Reset Instrument Objects
instrreset;     % clear all open objects


end

