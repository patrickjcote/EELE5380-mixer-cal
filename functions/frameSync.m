function [symsRx,sto,n0] = frameSync(Irx,Qrx,syncSyms,sps,frameLen)
%% frameSync.m
%
%   Synchronize to the start of a known sequence of symbols and determine
%   the best sample timing offset. Return complex sliced symbols.
%
%   INPUTS:
%       Irx         Baseband I samples
%       Qrx         Baseband Q samples
%       syncSyms    Frame start training symbols
%       sps         Samples per symbol
%       frameLen    Total symbols in frame
%   OUTPUTS:
%       symsRx      Complex valued symbols
%       sto         Sample Timing Offset
%       n0          Frame Start Symbol Offset
%
%   2019 - Patrick Cote
%   EELE 5380 - Adv. Signals and Systems

    %% Symbol Timing and Frame Sync
    N = floor(length(Irx)/sps)-frameLen-1;
    stoVec = zeros(sps,2);
    % For each possible sample timing offset xcorrelate with the known sync
    % symbols. Save the max correlation peak and symbol index for each sto
    for sto = 1:sps
        symsRx = zeros(N,1);
        for n = 1:N
            k = n*sps + sto - 1;
            symsRx(n) = Irx(k) + 1i*Qrx(k);
        end
        cor = xcorr(symsRx,syncSyms);
        n0 = max([length(symsRx),length(syncSyms)]);
        [corPeak, n0Ndx] = max(abs(cor(n0:end)));
        stoVec(sto,:) = [corPeak n0Ndx];
    end
    
    % Find the max correlation peak to determine sample timing offset
    [~,sto] = max(stoVec(:,1));

    % Find the frame start symbol offset for the given sto
    n0 = (stoVec(sto,2));

    %% Symbol Slicer
    % Starting at the first sync symbol, slice all samples in the frame len
    symsRx = zeros(frameLen,1);
    for n = 1:frameLen
        k = (n-1)*sps + sto + n0*sps - 1;
        symsRx(n) = (Irx(k) + 1i*Qrx(k));
    end
    
    %% Phase Offset Correction
    % Calculate an average phase offset from the known symbols
    phaseOFF = (angle(symsRx(1:length(syncSyms))) - angle(syncSyms))*180/pi;
    phaseOffset = mean(wrapTo180(phaseOFF));
    % De-rotate the received symbols
    symsRx = symsRx.*exp(-1i*phaseOffset*pi/180);
    IrxCorr = real((Irx + 1i*Qrx).*exp(-1i*phaseOffset*pi/180));
   
%     % Plot
%     sto0 = n0*sps + sto;
%     symNdx = (0:frameLen-1)*sps + sto0 - 1;
%     n = 1:length(IrxCorr);
%     figure;
%     plot(n,IrxCorr,symNdx,IrxCorr(symNdx),'x')
end