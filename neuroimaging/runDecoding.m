function runDecoding(threshType)
if ~exist('threshType','var')
    threshType = 'fdr'; % 'none', 'p' or 'fdr'
end
threshVal = 0.05;


repoPath = 'C:\Users\sebas\OneDrive - McGill University\dataBig';
dataDir = 'C-derived\DecodingHR';
funPath = fullfile(repoPath,dataDir,'fun');
funLevel_in = 'zSin';
funLevel_out = 'zSin/decoding';
subjList = {'02jp' '03sk' '04sp' '05bm' '06sb' '07bj'}';
fileSuffix_in = '_maskSinAndHrFit.mat';
fileSuffix_out = '_decoding.mat';



disp(['IN: Sinusoidal BOLD responses from anatomical V1 ROI (' fullfile(dataDir,funLevel_in) ')'])
disp('F(IN)=OUT: threshold included voxels and decode ROI response pattern to predict stimulus orientation')
disp(['OUT: figures and stats (' fullfile(dataDir,funLevel_in) ')'])



%% Load data
dAll = cell(size(subjList,1),1);
for subjInd = 1:size(subjList,1)
    load(fullfile(funPath,funLevel_in,[subjList{subjInd} fileSuffix_in]),'d');
    dAll{subjInd} = d;
end
d = dAll; clear dAll

%% Pipe data
% Threshold and average voxels in cartesian space
dP = d;
dP2 = cell(size(dP));
for subjInd = 1:length(dP)
    switch threshType
        % no voxel selection
        case 'none'
            % voxel selection cross-validated between sessions
        case 'p'
            indSess1 = dP{subjInd}.sess1.P<threshVal;
            indSess2 = dP{subjInd}.sess2.P<threshVal;
        case 'fdr'
            indSess1 = dP{subjInd}.sess1.FDR<threshVal;
            indSess2 = dP{subjInd}.sess2.FDR<threshVal;
        otherwise
            error('X')
    end
    dP{subjInd}.sess1.xData = dP{subjInd}.sess1.xData(:,indSess2,:);
    dP{subjInd}.sess1.F     = dP{subjInd}.sess1.F(:,indSess2,:);
    dP{subjInd}.sess1.FDR   = dP{subjInd}.sess1.FDR(:,indSess2,:);
    dP{subjInd}.sess1.P     = dP{subjInd}.sess1.P(:,indSess2,:);
    dP{subjInd}.sess2.xData = dP{subjInd}.sess2.xData(:,indSess2,:);
    dP{subjInd}.sess2.F     = dP{subjInd}.sess2.F(:,indSess2,:);
    dP{subjInd}.sess2.FDR   = dP{subjInd}.sess2.FDR(:,indSess2,:);
    dP{subjInd}.sess2.P     = dP{subjInd}.sess2.P(:,indSess2,:);
    
    sessList = fields(dP{subjInd});
    for sessInd = 1:length(sessList)
        dP2{subjInd,sessInd} = dP{subjInd}.(sessList{sessInd});
    end
    dP{subjInd} = [];
end
dP = dP2; clear dP2



%% Run svm
acc.cart     = nan(size(dP));
acc.cartReal = nan(size(dP));
acc.cartImag = nan(size(dP));
acc.pol      = nan(size(dP));
acc.polMag   = nan(size(dP));
acc.polDelay = nan(size(dP));
nObs         = nan(size(dP));
for i = 1:numel(dP)
    p.nVox = size(dP{i}.xData,2);
    p.nSamplePaired = size(dP{i}.xData,1);
    
    x1 = dP{i}.xData(:,:,1);
    y1 = 1.*ones(p.nSamplePaired,1);
    k1 = (1:p.nSamplePaired)';
    
    x2 = dP{i}.xData(:,:,2);
    y2 = 2.*ones(p.nSamplePaired,1);
    k2 = (1:p.nSamplePaired)';
    
    
    y = cat(1,y1,y2); clear y1 y2
    k = cat(1,k1,k2); clear k1 k2
    
%     %add an artificial offset for validation purposes
%     x2std = mean(abs(x2(:)))./std(abs(x2(:)));
%     [X,Y] = pol2cart(angle(x2),abs(x2) + x2std*0.2);
%     x2 = complex(X,Y);
      

    % Cartesian SVM
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % cartesian space normalization (mean=(0,0), std=1)
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % convert to cartesian
        x = cat(2,real(x),imag(x));
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 2 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.cart(i) = sum(yTe==y)./nObs(i);
    
    
    % Cartesian SVM (amplitude)
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % convert to response amplitude
        x = real(x);
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 2 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.cartReal(i) = sum(yTe==y)./nObs(i);
    
    
    % Cartesian SVM (off-amplitude)
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % convert to response amplitude
        x = imag(x);
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 2 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.cartImag(i) = sum(yTe==y)./nObs(i);
    
    
    % Polar SVM
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % convert to polar
        x = cat(2,angle(x),abs(x));
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 2 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.pol(i) = sum(yTe==y)./nObs(i);
    
    
    % Polar SVM (magnitude)
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % convert to polar rho
        x = abs(x);
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 2 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.polMag(i) = sum(yTe==y)./nObs(i);
    
    
    % Polar SVM (delay)
    kList = unique(k);
    yTr = nan(length(y),length(kList));
    yTe = nan(length(y),1);
    yHatTr = nan(length(y),length(kList));
    yHatTe = nan(length(y),1);
    for kInd = 1:length(kList)
        x = cat(1,x1,x2);
        
        % split train and test
        te = k==kList(kInd);
        
        % polar space normalization (rho=1, theta=0)
        rho = abs(mean(x(~te,:),1));
        theta = angle(mean(x(~te,:),1));
        [X,Y] = pol2cart(angle(x)-theta,abs(x)./rho);
        x = complex(X,Y); clear X Y
        
        % convert to polar theta
        x = angle(x);
        
        % final zScore
        x = x./std(x(~te,:),[],1) - mean(x(~te,:),1);
        
        % runSVM
        model = svmtrain(y(~te,:),x(~te,:),'-t 0 -q');
%         w = model.sv_coef'*model.SVs;
%         b = model.rho;
%         yHat = cat(2,real(x(~te,:)),imag(x(~te,:)))*w';
        [yTr(~te,kInd), ~, yHatTr(~te,kInd)] = svmpredict(y(~te,:),x(~te,:),model,'-q');
        [yTe(te,1), ~, yHatTe(te,1)] = svmpredict(y(te,:),x(te,:),model,'-q');
    end
    nObs(i) = length(y);
    acc.polDelay(i) = sum(yTe==y)./nObs(i);
end
disp('Full response (cartesian)')
% acc.cart
% P = binocdf(acc.cart.*nObs,nObs,0.5,'upper')
% mean(acc.cart,2)
% P = binocdf(sum(acc.cart.*nObs,2),sum(nObs,2),0.5,'upper')
mean(acc.cart(:))
P = binocdf(sum(acc.cart(:).*nObs(:)),sum(nObs(:)),0.5,'upper')

disp('Response amp (cartesian)')
% acc.cartReal
% P = binocdf(acc.cartReal.*nObs,nObs,0.5,'upper')
% mean(acc.cartReal,2)
% P = binocdf(sum(acc.cartReal.*nObs,2),sum(nObs,2),0.5,'upper')
mean(acc.cartReal(:))
P = binocdf(sum(acc.cartReal(:).*nObs(:)),sum(nObs(:)),0.5,'upper')

disp('Response delay (cartesian)')
% acc.cartImag
% P = binocdf(acc.cartImag.*nObs,nObs,0.5,'upper')
% mean(acc.cartImag,2)
% P = binocdf(sum(acc.cartImag.*nObs,2),sum(nObs,2),0.5,'upper')
mean(acc.cartImag(:))
P = binocdf(sum(acc.cartImag(:).*nObs(:)),sum(nObs(:)),0.5,'upper')

disp('Response magnitude')
% acc.polMag
% P = binocdf(acc.polMag.*nObs,nObs,0.5,'upper')
% mean(acc.polMag,2)
% P = binocdf(sum(acc.polMag.*nObs,2),sum(nObs,2),0.5,'upper')
mean(acc.polMag(:))
P = binocdf(sum(acc.polMag(:).*nObs(:)),sum(nObs(:)),0.5,'upper')

disp('Response delay')
% acc.polDelay
% P = binocdf(acc.polDelay.*nObs,nObs,0.5,'upper')
% mean(acc.polDelay,2)
% P = binocdf(sum(acc.polDelay.*nObs,2),sum(nObs,2),0.5,'upper')
mean(acc.polDelay(:))
P = binocdf(sum(acc.polDelay(:).*nObs(:)),sum(nObs(:)),0.5,'upper')


