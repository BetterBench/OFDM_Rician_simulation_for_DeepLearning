clear;
clc;
close all;
%10是信噪比，100是自定义产生的帧的数量
BERTool_QPSK_OFDM_RicianChannel_LSEstimation(10, 10000)
function [BER, numBits] = BERTool_QPSK_OFDM_RicianChannel_LSEstimation(EbNo, Nframes)

%%%%%%%%%%%%%%%%%%%%%%%%%
%子载波数量256
%循环前缀64
%一帧数据就是2×（256+64）=2×320大小
%QPSK的调制方式
    persistent FullOperatingTime

    % Display Line on the Start of Imitation Modeling
    disp('======================================');
    % Start Time
    tStart = clock;
    % Total Duration of Imitation Modeling
    % Saving for each trials. To restart need 'clear all' command.
    if isempty(FullOperatingTime)
        FullOperatingTime = 0;
    end
    
    
    %%%%% Initial Information Source %%%%%
    
    % Symbol Rate
    Rs = 100e3;
    % Symbol Duration
%     Ts = 1/Rs;
    
    %%%%% QPSK Modulation %%%%%
    
    % Number of Bits in QPSK Symbol by definition
    k = 1;
    
    
    % QPSK Modulator Object
%     QPSKModulator = comm.QPSKModulator( ...
%         'PhaseOffset', pi/4, ...
%         'BitInput', true, ...
%         'SymbolMapping', 'Gray' ...
%     );
% 
%     % QPSK Demodulator Object
%     QPSKDemodulator = comm.QPSKDemodulator( ...
%         'PhaseOffset', QPSKModulator.PhaseOffset, ...
%         'BitOutput', QPSKModulator.BitInput, ...
%         'SymbolMapping', QPSKModulator.SymbolMapping, ...
%         'DecisionMethod', 'Hard decision' ...
%     );
    BPSKModulator = comm.BPSKModulator('PhaseOffset',pi/4);

    BPSKDemodulator = comm.BPSKDemodulator( 'PhaseOffset', BPSKModulator.PhaseOffset, ...
        'DecisionMethod', 'Hard decision' ...
    );
    %%%%% OFDM Modulation %%%%%
    
    % Number of Subcarriers (equal to Number of FFT points)
    numSC = 256;
    
    % Guard Bands Subcarriers
    GuardBandSC = [10; 10];
    
    % Central Null Subcarrier
    DCNull = true;
    DCNullSC = numSC/2 + 1;
    
    % Number of Pilot Subcarriers
    numPilotSC = 10;
    % Location of Pilot Subcarriers
    PilotSC = round(linspace(GuardBandSC(1) + 5, numSC - GuardBandSC(2) - 6, numPilotSC))';
    
    % Length of Cyclic Prefix
    lenCP = numSC/4;
    
    
    % OFDM Modulator Object
    OFDMModulator = comm.OFDMModulator( ...
        'FFTLength', numSC, ...
        'NumGuardBandCarriers', GuardBandSC, ...
        'InsertDCNull', DCNull, ...
        'PilotInputPort', true, ...
        'PilotCarrierIndices', PilotSC, ...
        'CyclicPrefixLength', lenCP ...
    );

    % OFDM Demodulator Object
    OFDMDemodulator = comm.OFDMDemodulator(OFDMModulator);
    

    % Number of Data Subcarriers
    numDataSC = info(OFDMModulator).DataInputSize(1);

    % Size of Data Frame
    szDataFrame = [k*numDataSC 1];
    % Size of Pilot Frame
    szPilotFrame = info(OFDMModulator).PilotInputSize;


    %%%%% Transionospheric Communication Channel %%%%%
    
   % Discrete Paths Relative Delays
    PathDelays = [0 0.01 0.02 0.03];
    % Discrete Paths Average Gains
    PathAvGains = [0 -6 -9 -12];
    % Discrete Paths K Factors
    K = 10;
    % Max Doppler Frequency Shift
    fD = 200;
    
    % Rician Channel Object
    RicianChannel = comm.RicianChannel( ...
        'SampleRate', Rs, ...%采样率
        'PathDelays', PathDelays, ...%路径延迟
        'AveragePathGains', PathAvGains, ...%路径增益
        'NormalizePathGains', true, ...
        'KFactor', K, ...%K因子
        'MaximumDopplerShift', fD, ...%最大多普勒频移
        'DirectPathDopplerShift', zeros(size(K)), ...
        'DirectPathInitialPhase', zeros(size(K)), ...
        'DopplerSpectrum', doppler('Jakes') ...%采用的Jakes信道模型
    );

    % Delay in Rician Channel Object
    ChanDelay = info(RicianChannel).ChannelFilterDelay;    

    % AWGN Channel Object
    AWGNChannel = comm.AWGNChannel( ...
        'NoiseMethod', 'Signal to noise ratio (SNR)', ...
        'SNR', EbNo + 10*log10(k) + 10*log10(numDataSC/numSC) ...       
    );

    
    %%%%% Imitation Modeling %%%%%
    
    % Import Java class for BERTool
    % import com.mathworks.toolbox.comm.BERTool;    
    
    % BER Calculator Object
    BERCalculater = comm.ErrorRate;
    % BER Intermediate Variable
    BERIm = zeros(3,1);
    
    perFrameLength = numSC+ lenCP;
    %% 初始化一个存储帧数据的容器
    % 初始化一个训练集label的容量
    initialLabel = zeros(1,k*numDataSC);
    % 初始化容器
    frameStore = helperModClassFrameStoreTest(...
         Nframes,perFrameLength,initialLabel);
    
    
    %% 仿真发送和接收
    tLoop1 = clock;
    % 一个循环一帧数据
    for frameNum = 1:Nframes      
        % >>> Transmitter >>>
        
        % Generation of Data Bits
        BitsTx = randi([0 1], szDataFrame);
        
        % QPSK Modulation
%         SignalTx1 = QPSKModulator(BitsTx);

        SignalTx1 = BPSKModulator(BitsTx);
        
        % Generation of Pilot Signals
        PilotSignalTx = complex(ones(szPilotFrame), zeros(szPilotFrame));
        % OFDM Modulation
        SignalTx2 = OFDMModulator(SignalTx1, PilotSignalTx);
        
        % Power of Transmitted Signal
        SignalTxPower = var(SignalTx2);
        
        
        % >>> Transionospheric Communication Channel >>>
        
        % Adding zero samples to the end of Transmitted Signal
        % to not lose shifted samples caused by delay after Rician Channel
        SignalTx2 = [SignalTx2; zeros(ChanDelay, 1)];
        % Rician Channel
        SignalChan1 = RicianChannel(SignalTx2);
        % Removing first ChanDelay samples and
        % selection of Channel's Signal related to Transmitted Signal
        SignalChan1 = SignalChan1(ChanDelay + 1 : end);
        
        % AWGN Channel
        AWGNChannel.SignalPower = SignalTxPower;
        SignalChan2 = AWGNChannel(SignalChan1);
        
        % 存储发送帧
        frame = reshape(SignalChan2,[],1);%转换成一列的矩阵，方便进行计算
        perFrameLabel =  BitsTx;
   
        %把发送帧添加到帧容器
        add(frameStore, frame, perFrameLabel);%modulationTypes(modType));
        
        % >>> Receiver >>>
        
        % OFDM Demodulation
        [SignalRx1, PilotSignalRx] = OFDMDemodulator(SignalChan2);
    
        % LS Channel Estimation
        % Channel Frequency Response
        ChanFR_dp = PilotSignalRx ./ PilotSignalTx;
        ChanFR_int = interp1( ...
            PilotSC, ...
            ChanFR_dp, ...
            GuardBandSC(1) + 1 : numSC - GuardBandSC(2), ...
            'pchip' ...
        );
        ChanFR_int([PilotSC; DCNullSC] - GuardBandSC(1)) = [];
        % LS Solution
        SignalRx2 = SignalRx1 ./ ChanFR_int.';
        
        % QPSK Demodulation
%         BitsRx = QPSKDemodulator(SignalRx2);
        BitsRx = BPSKDemodulator(SignalRx2);
        
        % BER Calculation
        BERIm = BERCalculater(BitsTx, BitsRx);
        
    end
    
    %% 划分数据集为训练集、验证集、测试集
    % 训练集百分之占比
    percentTrainingSamples = 80;
    % 验证集百分之占比
    percentValidationSamples = 10;
    % 测试集百分之占比
    percentTestSamples = 10;
    % 划分数据集
    [mcfsTraining,mcfsValidation,mcfsTest] = splitData(frameStore,...
    [percentTrainingSamples,percentValidationSamples,percentTestSamples]);
    
    % 从训练集中返回存储的帧和相应的标签。
    [rxTraining,rxTrainingLabel] = get(mcfsTraining);
    
    % 从验证集中返回存储的帧和相应的标签。
    [rxValidation,rxValidationLabel] = get(mcfsValidation);

    % 从测试集中返回存储的帧和相应的标签。
    [rxTest,rxTestLabel] = get(mcfsTest);
    % 存储划分的数据为.mat文件
      save bpsk-data10000 rxTraining rxTrainingLabel  rxValidation rxValidationLabel rxTest rxTestLabel;
    
    
    tLoop2 = clock;    
    
    %% 误码率计算
    BER = BERIm(1);
    numBits = BERIm(3);
    disp(['BER = ', num2str(BERIm(1), '%.5g'), ' at Eb/No = ', num2str(EbNo), ' dB']);
    disp(['Number of bits = ', num2str(BERIm(3))]);
    disp(['Number of errors = ', num2str(BERIm(2))]);
    
    
    % Performance of Imitation Modeling
    Perfomance = BERIm(3) / etime(tLoop2, tLoop1);
    disp(['Perfomance = ', num2str(Perfomance), ' bit/sec']);    
    
    % Duration of this Imitation Modeling
    duration = etime(clock, tStart);
    disp(['Operating time = ', num2str(duration), ' sec']);
    
    % Total Duration of Imitation Modeling
    FullOperatingTime = FullOperatingTime + duration;
    assignin('base', 'FullOperatingTime', FullOperatingTime);

end