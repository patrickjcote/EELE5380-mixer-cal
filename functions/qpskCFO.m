function [fErr] = qpskCFO(Irx,Qrx,Fs)
%% frameSync.m
%
%   Calculate frequency offset of a QPSK signal using
%   a power of 4 algorithm. Frequency spur near 0 Hz corresponds to
%   -4x the carrier frequency offset
%
%   INPUTS:
%       Irx         Baseband I samples
%       Qrx         Baseband Q samples
%       Fs          Sample Rate
%       
%   OUTPUTS:
%       fErr        Frequency Offset
%
%   2019 - Patrick Cote
%   EELE 5380 - Adv. Signals and Systems 


    %% Power of 4
    x = (Irx+1i*Qrx).^4;
    
    %% FFT
    n = length(x);
    X = fft(x)/n;
    % Build a Frequency Vector
    fVec = Fs*(-n/2:n/2-1)/n;
    % Shift the FFT to be centered at zero, convert to dB
    PdB = 20*log10(fftshift(X));
    
    %% Find the max power peak and calculate the frequency error
    [~,ndx] = max(PdB);
    fErr = -fVec(ndx)/4;
    
end