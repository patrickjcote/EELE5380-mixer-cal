function [P, f] = fftPlot( x, fs, f_range, titleVec)
%% fftPlot.m - Plots the FFT of the input signal x
%
%   [P, f] = fftPlot( x, fs, f_range, windowNdx, sideNdx )
%
%   INPUT:
%   x           =   signal to be processed
%   fs          =   sampling rate of x          [sps]
%   f_range     =   Frequency range to plot     [f_low,f_high]
%
%   OUTPUT:
%   P    =   FFT power output vector            
%   f    =   frequency bin vector
%
%   2018 - Montana Tech - Patrick Cote


n = length(x);


%% FFT
X = fft(x);
f = fs*(0:(n/2))/n;
P = abs(X)/n;
P = P(1:floor(n/2)+1);
P(2:end-1) = 2*P(2:end-1);
P = 20*log10(P); 

A = angle(X)*180/pi;
A = A(1:floor(n/2)+1);
 

%% Plot
if ~exist('f_range','var')
    f_range = [f(1) f(end)];
elseif f_range<0
    f_range = [f(1) f(end)];
end

binSize = fs/n;

if ~exist('titleVec','var')
titleVec = ['FFT(x) - ',num2str(binSize),' Hz/bin'];
end


plot(f,P); grid;
title(titleVec);
xlim(f_range);
xlabel('f (Hz)')
ylabel('dB(|X|)')

% figure;
% plot(f,A); grid;
% title(titleVec);
% xlim(f_range);
% xlabel('f (Hz)')
% ylabel('deg')

end

