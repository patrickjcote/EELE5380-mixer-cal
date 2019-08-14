function [sigOut] = puncture(sigIn,punctPattern,llrValue)


%% If no LLR value, puncture input signal
if ~exist('llrValue','var')
    N = length(sigIn)/length(punctPattern);
    if mod(N,1)
        error('Signal must be integer number of puncturing pattern in length');
    end
    punctVec = logical(repmat(punctPattern,1,N));
    sigOut = sigIn(punctVec);  
else
%% Otherwise reinsert llr values according to puncture pattern
    nBits = sum(punctPattern);
    nPunc = length(punctPattern);
    pNDX = logical(punctPattern);
    llrVec = llrValue*ones(nPunc,1);
    N = length(sigIn)/nBits;
    if mod(N,1)
        error('Signal must be integer number of puncturing pattern in length');
    end

    for n = 1:N
        temp = zeros(nPunc,1);
        temp(~pNDX) = llrVec(~pNDX);
        temp(pNDX) = sigIn(nBits*(n-1)+1:nBits*n);
        sigOut(nPunc*(n-1)+1:nPunc*n) = temp;   
    end

end

end

