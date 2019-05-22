function [Irx,Qrx] = downConvert(RFrx,fLO,Fs,taps)
%% downConvert.m
%
%   Digitally downconvert a signal and filter with a simple moving average
%   FIR Filter.
%
%   INPUTS:
%       RFrx        Received RF samples
%       fLO         Digital Local Oscillator Frequency
%       Fs          Sample Rate
%       taps        # of evenly weighted taps for FIR moving average filter
%   OUTPUTS:
%       Irx         Baseband I samples
%       Qrx         Baseband Q samples
%
%   2019 - Patrick Cote
%   EELE 5380 - Adv. Signals and Systems

    %% Downconvert Received RF signal
    t = ((0:length(RFrx)-1)/Fs)';
    Irx = real(2*RFrx.*cos(2*pi*fLO*t));
    Qrx = real(2*RFrx.*sin(2*pi*fLO*t));

    % LPF
    if taps
        b = (1/taps)*ones(1,taps);
        Irx = filter(b,1,Irx);
        Qrx = filter(b,1,Qrx);
    end


end

