function [fOff] = fineCFO(pilotSyms,symsRx,f)
%fineCFO.m
%
%   Calculate Carrier Frequency Offset by determining mean phase difference
%   between symbols transitions
%
%   INPUT:
%       pilotSyms   known pilot symbols 
%       symsRx      received symbols
%       f           symbol rate
%   OUTPUT:
%       fOff        Frequency Offset
%
%   2019 - Patrick Cote
%   EELE 5380 - Adv. Signals and Systems 


    % Calculate angles between pilot symbols
    txAng = diff(angle(pilotSyms))*180/pi;
    % Calculate angles between received symbols
    rxAng = diff(angle(symsRx))*180/pi;
    % Calculate average phase offset
    avgOffset = mean(wrapTo180(txAng - rxAng));
    % Convert average phase offset to a frequency offset
    fOff = avgOffset*(f/360);

end