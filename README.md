# 莱斯信道下的OFDM仿真，进行发送数据帧的存储，存储为深度学习中训练模型的训练集、测试集、验证集

## 1 OFDM参数

调制方式QPSK
子载波数量256
一个OFDM有2个符号
循环前缀子载波的1/4，为64

## 2 数据集参数

发送端产生的一帧数据是2×225 = 450 ，作为数据集的标签

接受端一帧数据就是2×（256+64）=2*320 = 640，2表示IQ两个信号，640长度的帧数据作为数据集的每帧训练数据
## 3 莱斯信道的参数

```
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

```
## 4 数据存储的思路

首先初始化一个存储所有帧数据的容器

```
% 144行
frameStore = helperModClassFrameStoreTest(...
         Nframes,perFrameLength,initialLabel);
```

再把每一帧数据，放入到该容器当中

```
% 193行
add(frameStore, frame, perFrameLabel);%modulationTypes(modType));
```

最后划分容器里所有数据分为训练集、验证集、测试集

```
% 223行
[mcfsTraining,mcfsValidation,mcfsTest] = splitData(frameStore,...
    [percentTrainingSamples,percentValidationSamples,percentTestSamples]);
    
    % 从训练集中返回存储的帧和相应的标签。
    [rxTraining,rxTrainingLabel] = get(mcfsTraining);
    
    % 从验证集中返回存储的帧和相应的标签。
    [rxValidation,rxValidationLabel] = get(mcfsValidation);

    % 从测试集中返回存储的帧和相应的标签。
    [rxTest,rxTestLabel] = get(mcfsTest);
```

## 5 运行

实验环境：MATLAB 

自定义发送帧的数量：修改第五行第二个参数

自定义信噪比：修改第五行，第一个参数



## ## 6 源码下载
https://github.com/823316627bandeng/OFDM_Rician_simulation_for_DeepLearning

