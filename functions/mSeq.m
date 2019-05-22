function [mseq] = mSeq(n,taps)
%% mSeq.m
%
%   Produce maximal length sequence using linear feedback shift registers
%
%   INPUTS:
%       n       number of registers
%       taps    Feedback tap indicies
%   OUTPUT:
%       mseq    generated m-sequence
%
%   2018 - Patrick Cote
%   EELE 591 - Special Topics

    % Initialize LFSRs
    N = 2^n-1;          % Length of M-Sequence
    x = ones(n,1);      % Initialize register states
    mseq = zeros(N,1);  % Initialize output

    for k = 1:N
        % M-Sequence output = state of last register
        mseq(k) = x(end);
        % XOR sum the feedback taps
        xfb = mod(sum(x(taps)),2);
        % Shift Registers
        x = circshift(x,1);
        % Feedback XOR sum into the first state
        x(1) = xfb;
    end

end