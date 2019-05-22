function [symsRxCor, fOff] = correctCFO(pilotSyms,symsRx,Fsym)
%% correctCFO.m
%
%   Calculate Carrier Frequency Offset by determining mean phase difference
%   between symbols transitions. Derotate each symbol
%
%   INPUT:
%       pilotSyms   known pilot symbols 
%       symsRx      received symbols
%       Fsym        symbol rate
%   OUTPUT:
%       fOff        Frequency Offset
%
%   2019 - Patrick Cote
%   EELE 5380 - Adv. Signals and Systems 


    % Calculate angles between pilot symbols
    txAng = diff(angle(pilotSyms))*180/pi;
    % Calculate angles between received symbols
    rxAng = diff(angle(symsRx(1:length(pilotSyms))))*180/pi;
    % Calculate average phase offset
    avgOffset = mean(wrapTo180(txAng - rxAng));
    fOff = avgOffset*(Fsym/360);
    angCor = (0:length(symsRx)-1)'*avgOffset*pi/180;
    symsRxCor = symsRx.*exp(1i*angCor);

end