classdef helperModClassFrameStoreTest < handle


  properties (SetAccess=private)
    %NumFrames Number of frames in the frame store
    NumFrames = 0
    %MaximumNumFrames Capacity of frame store
    MaximumNumFrames
    %SamplesPerFrame Samples per frame
    SamplesPerFrame
    %Labels Set of expected labels
    Labels
    
   
    
    Labelnumber = 0
  end
  
  properties (Access=private)
    Frames
    Label

  end
  
  methods
      %% 把帧封装成一个对象
    function obj = helperModClassFrameStoreTest(varargin)

      inputs = inputParser;
      addRequired(inputs, 'MaximumNumFrames')
      addRequired(inputs, 'SamplesPerFrame')
      addRequired(inputs, 'Labels')
      parse(inputs, varargin{:})
      
      obj.SamplesPerFrame = inputs.Results.SamplesPerFrame;%每种调制方式的数量
      obj.MaximumNumFrames = inputs.Results.MaximumNumFrames;%一帧数据的大小
      obj.Labels = inputs.Results.Labels;%标签的大小
      
      obj.Frames = ...
      zeros(obj.SamplesPerFrame,obj.MaximumNumFrames);
      obj.Label = repmat(obj.Labels,obj.MaximumNumFrames,1);
      
     
    end
    
    %% 添加帧
    function add(obj,frames,label,varargin)
     
      %一帧占一列
       numNewFrames = size(frames,2);
       
       
      FrameStartIdx = obj.NumFrames+1;
      LabelStartIdx = obj.Labelnumber +1;

     
      FrameEndIdx = obj.NumFrames+numNewFrames;
      obj.Frames(:,FrameStartIdx:FrameEndIdx) = frames;% 帧的IQ矩阵是横着存储的
      obj.Label(LabelStartIdx,:) = label;
      
      obj.NumFrames = obj.NumFrames + numNewFrames;
      obj.Labelnumber = obj.Labelnumber+ 1;
    end
    
    %% 获取帧数据和标签
    function [frames,labels] = get(obj)
        
          I = real(obj.Frames(:,1:obj.NumFrames));
          Q = imag(obj.Frames(:,1:obj.NumFrames));
          %第一维是帧的数量，第二维是通道数默认为1，第三维是2，表示IQ两列，第四维是一帧的长度。三四维组成一帧的长和宽。
          I = permute(I,[2 3 1]);
          Q = permute(Q,[2 3 1]);
          tframes = cat(3,I,Q);%3表示在第３维度进行叠加矩阵
          s1 = size(tframes,1);
          s2 = size(tframes,3);
          %数据集中的每一帧变成一维，转换成长度为６４０的一行。
          frames = reshape(tframes,s1,s2);
          size(frames)

      labels = obj.Label(1:obj. MaximumNumFrames,:);
    end
    
    %% 划分数据集成训练集、验证集、测试集
    function [fsTraining,fsValidation,fsTest] = ...
        splitData(obj,splitPercentages)
      
    
    numFrames = obj.Labelnumber;
    

      fsTraining = helperModClassFrameStoreTest(...
        ceil(obj.MaximumNumFrames*splitPercentages(1)/100), ...
        obj.SamplesPerFrame, obj.Labels);
      fsValidation = helperModClassFrameStoreTest(...
        ceil(obj.MaximumNumFrames*splitPercentages(2)/100), ...
        obj.SamplesPerFrame, obj.Labels);
      fsTest = helperModClassFrameStoreTest(...
        ceil(obj.MaximumNumFrames*splitPercentages(3)/100), ...
        obj.SamplesPerFrame, obj.Labels);
   
        numTrainingFrames = round(numFrames*splitPercentages(1)/100);
        numValidationFrames = round(numFrames*splitPercentages(2)/100);
        numTestFrames = round(numFrames*splitPercentages(3)/100);
        extraFrames = sum([numTrainingFrames,numValidationFrames,numTestFrames]) - numFrames;
        if (extraFrames > 0)
          numTestFrames = numTestFrames - extraFrames;
        end
        
        
        shuffleIdx = randperm(numFrames);
        frames = obj.Frames(:,shuffleIdx);
        TempLabel = obj.Label(shuffleIdx,:);

        for TraininglabelIndex = 1:numTrainingFrames
              add(fsTraining, ...
              frames(:,TraininglabelIndex), ...
             TempLabel(TraininglabelIndex,:));
        end
        for ValidationlabelIndex = 1: numValidationFrames
             add(fsValidation, ...
              frames(:,numTrainingFrames+ValidationlabelIndex), ...
             TempLabel((numTrainingFrames+ValidationlabelIndex),:));
         
        end
        for TestlabelIndex = 1 :numTestFrames
             add(fsTest, ...
              frames(:,numTrainingFrames+numValidationFrames+TestlabelIndex), ...
              TempLabel((numTrainingFrames+numValidationFrames+TestlabelIndex),:));
        end
        
        
      
      % Shuffle new frame stores
      shuffle(fsTraining);
      shuffle(fsValidation);
      shuffle(fsTest);
    
    end
    
     function shuffle(obj)
      %shuffle  Shuffle stored frames
      %   shuffle(FS) shuffles the order of stored frames.
      % 打乱顺序，类似与扑克中的洗牌操作
      shuffleIdx = randperm(obj.NumFrames);
      obj.Frames = obj.Frames(:,shuffleIdx);
      obj.Label = obj.Label(shuffleIdx,:);
    end
  end
end


   

