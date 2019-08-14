function [encBlock, dataBits] = buildencBlock(blockLen,FECtype,rate,rng_seed)


rng(rng_seed);          % Random Seed

if strcmp(FECtype, 'None') % No channel coding
    dataBits = randi([0 1],blockLen,1);
    encBlock = dataBits;
else
    switch rate
        case 2
            r = 2/3;
        case 3
            r = 3/4;
        case 4
            r = 5/6;
        case 5
            r = 1/3;
        otherwise
            r = 1/2;
    end
    switch FECtype
        case 'Convolutional'
            % Convolutional Coding
            dataBits = randi([0 1],blockLen*r,1);
            % Tail bits to flush the encoder
            dataBits(end-31:end) = zeros(32,1);
            encBlock = convEncode(dataBits,rate);
        case 'LDPC'
            dataBits = randi([0 1],floor(blockLen*r),1);
            encBlock = ldpcEncode(dataBits,blockLen,r);
        case 'Turbo'
            dataBits = randi([0 1],floor((blockLen-12)*r),1);
            encBlock = turbEncode(dataBits,rate);
        otherwise
            dataBits = randi([0 1],blockLen,1);
            encBlock = dataBits;
    end
    
    length(dataBits)/length(encBlock)
    
end