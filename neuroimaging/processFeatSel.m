function processFeatSel(p,verbose)
if ~exist('verbose','var')
    verbose = 1;
end
if ~isfield(p,'figOption') || isempty(p.figOption)
    p.figOption.verbose = 1;
    p.figOption.subjInd = 1;
    p.figOption.sessInd = 1;
end


%% Define paths
subjList = {'02jp' '03sk' '04sp' '05bm' '06sb' '07bj'};
if ismac
    repoPath = '/Users/sebastienproulx/OneDrive - McGill University/dataBig';
else
    repoPath = 'C:\Users\sebas\OneDrive - McGill University\dataBig';
end
        funPath = fullfile(repoPath,'C-derived\DecodingHR\fun');
            inDir  = 'd';
            outDir  = 'd';
%make sure everything is forward slash for mac, linux pc compatibility
for tmp = {'repoPath' 'funPath' 'inDir' 'outDir'}
    eval([char(tmp) '(strfind(' char(tmp) ',''\''))=''/'';']);
end
clear tmp

%% Load data
dAll = cell(size(subjList,1),1);
for subjInd = 1:size(subjList,2)
    curFile = fullfile(funPath,inDir,[subjList{subjInd} '.mat']);
    if verbose; disp(['loading: ' curFile]); end
    load(curFile,'res');
%     for sessInd = 1:2
%         sess = ['sess' num2str(sessInd)];
%         if isfield(res.(sess),'featSel')
%             res.(sess) = rmfield(res.(sess),'featSel');
%         end
%     end
    dAll{subjInd} = res;
end
d = dAll; clear dAll
sessList = fields(d{1});


%% Reorganize
dP = cell(size(d,2),length(sessList));
for subjInd = 1:length(d)
    for sessInd = 1:length(sessList)
        sess = ['sess' num2str(sessInd)];
        dP{subjInd,sessInd} = d{subjInd}.(sessList{sessInd});
        d{subjInd}.(sessList{sessInd}) = [];
    end
end
d = dP; clear dP

%% Precompute flattened voxel ecc distribution on fov and delay map
if p.featSel.fov.doIt && strcmp(p.featSel.fov.threshMethod,'empirical')
    disp('Flattening ecc dist: computing hemiL')
    voxProp.L = flattenEccDist(d,'L',p,1);
    disp('Flattening ecc dist: computing hemiR')
    voxProp.R = flattenEccDist(d,'R',p,1);
    disp('Flattening ecc dist: done')
    
    
    p.featSel.fov.empirical.padFac             = 1.2;
    p.featSel.fov.empirical.minContPercentArea = 0.05;
    disp('Delay map for contour: computing hemiL')
    cont.L = prepareDelayFovContour(d,voxProp.L,p);
    disp('Delay map for contour: computing hemiR')
    cont.R = prepareDelayFovContour(d,voxProp.R,p);
    disp('Delay map for contour: done')
    
    % Repack voxProp into d
    for subjInd = 1:size(d,1)
        for sessInd = 1:size(d,2)
            d{subjInd,sessInd}.voxProp.L = voxProp.L{subjInd};
            d{subjInd,sessInd}.voxProp.R = voxProp.R{subjInd};
        end
        voxProp.L{subjInd} = {};
        voxProp.R{subjInd} = {};
    end
    clear voxProp
end

%% Setting fov contour params
if p.featSel.fov.doIt && strcmp(p.featSel.fov.threshMethod,'empirical')
    p.featSel.fov.empirical.auto(1).smList           = 0.001; % ecc
    p.featSel.fov.empirical.auto(1).mergeRadiusList  = 0.75; % ecc
    p.featSel.fov.empirical.auto(1).marginRadiusList = 0.40; % ecc
    p.featSel.fov.empirical.auto(2).smList           = 0.25; % ecc
    p.featSel.fov.empirical.auto(2).mergeRadiusList  = 0.75; % ecc
    p.featSel.fov.empirical.auto(2).marginRadiusList = 0.40; % ecc
end

%% Feature selection
featSel_areaAndFov = cell(size(d));
f.L = cell(size(d));
f.R = cell(size(d));
% disp('computing feature selection stats')
for subjInd = 1:size(d,1)
    disp(['subj:' num2str(subjInd) '/' num2str(size(d,1))])
    for sessInd = 1:size(d,2)
        p.subjInd = subjInd;
        p.sessInd = sessInd;
        hemi = 'L';
        [featValLR.(hemi),featMethodLR.(hemi),featIndInLR.(hemi),featInfoLR.(hemi),f.(hemi){subjInd,sessInd}] = getFeatSel_areaAndFov(cont.(hemi){subjInd,sessInd},d{subjInd,sessInd}.voxProp.(hemi),p);
        hemi = 'R';
        [featValLR.(hemi),featMethodLR.(hemi),featIndInLR.(hemi),featInfoLR.(hemi),f.(hemi){subjInd,sessInd}] = getFeatSel_areaAndFov(cont.(hemi){subjInd,sessInd},d{subjInd,sessInd}.voxProp.(hemi),p);
        
        % Combine hemifields
        featVal = nan(size(d{subjInd,sessInd}.voxProp.(hemi).hemifield));
        featIndIn = nan(size(d{subjInd,sessInd}.voxProp.(hemi).hemifield));
        hemi = 'L';
        featVal(d{subjInd,sessInd}.voxProp.(hemi).hemifield) = featValLR.(hemi);
        featIndIn(d{subjInd,sessInd}.voxProp.(hemi).hemifield) = featIndInLR.(hemi);
        hemi = 'R';
        featVal(d{subjInd,sessInd}.voxProp.(hemi).hemifield) = featValLR.(hemi);
        featIndIn(d{subjInd,sessInd}.voxProp.(hemi).hemifield) = featIndInLR.(hemi);
        featMethod = featMethodLR.L;
        featInfo = featInfoLR.L;
        
        featSel_areaAndFov{subjInd,sessInd}.featVal = featVal; clear featVal featValLR;
        featSel_areaAndFov{subjInd,sessInd}.featIndIn = featIndIn; clear featIndIn featIndInLR;
        featSel_areaAndFov{subjInd,sessInd}.featMethod = featMethod; clear featMethod featMethodLR;
        featSel_areaAndFov{subjInd,sessInd}.featInfo = featInfo; clear featInfo featInfoLR;
    end
end

fIndList = [1 2 4 7 9 10];
supTitleList = {'removing small islands' '1st contours' '1st contours processing' '2nd contours' '2nd contours processing' 'Final contours'};
% fAll.L = cell(size(fIndList));
% fAll.R = cell(size(fIndList));
fAll = cell(size(fIndList));
% supTitleList = {'Contour Definition' 'Contour Processing' 'Final Contour' 'Contour Masking'};
for i = 1:length(fIndList)
    fInd = fIndList(i);
%     fAll.L{i} = figure('WindowStyle','docked');
    fAll{i} = figure('WindowStyle','docked');
    [ha, pos] = tight_subplot(size(d,2), size(d,1)*2, 0, 0.1, 0); delete(ha);
    for subjInd = 1:size(d,1)
        for sessInd = 1:size(d,2)
            hemi = 'L';
            ax.(hemi) = copyobj(f.(hemi){subjInd,sessInd}(fInd).Children,fAll{i});
            ax.(hemi).DataAspectRatioMode = 'auto';
            ax.(hemi).PlotBoxAspectRatioMode = 'auto';
%           ax = copyobj(f.(hemi){subjInd,sessInd}(fInd).Children,fAll.(hemi){i});
%             ax.Position = pos{(sessInd-1)*size(d,1)+subjInd};
            ax.(hemi).Position = pos{(sessInd-1)*(size(d,1)*2)+(subjInd*2-1)};
            ax.(hemi).Colormap = f.(hemi){subjInd,sessInd}(fInd).Children.Colormap;
            drawnow
            
            hemi = 'R';
            ax.(hemi) = copyobj(f.(hemi){subjInd,sessInd}(fInd).Children,fAll{i});
            ax.(hemi).DataAspectRatioMode = 'auto';
            ax.(hemi).PlotBoxAspectRatioMode = 'auto';
            ax.(hemi).Position = pos{(sessInd-1)*(size(d,1)*2)+(subjInd*2-1)+1};
            ax.(hemi).Colormap = f.(hemi){subjInd,sessInd}(fInd).Children.Colormap;
            drawnow
            
            yLim = [-1 1].*max(abs([ax.L.YLim ax.R.YLim ax.L.XLim(1) ax.R.XLim(2)]));
            xLim = yLim(2);
            ax.L.YLim = yLim;
            ax.R.YLim = yLim;
            ax.L.XLim = [-xLim 0];
            ax.R.XLim = [0 xLim];
            drawnow
            
            ax.L.PlotBoxAspectRatio = [0.5 1 1];
            ax.R.PlotBoxAspectRatio = [0.5 1 1];
            
            ax.L.YAxis.Visible = 'off';
            ax.R.YAxis.Visible = 'off';
        end
    end
    suptitle(supTitleList{i})
    
%     fInd = fIndList(i);
%     fAll.R{i} = figure('WindowStyle','docked');
%     [ha, pos] = tight_subplot(size(d,2), size(d,1), 0, 0.1, 0); delete(ha);
%     for subjInd = 1:size(d,1)
%         for sessInd = 1:size(d,2)
%             ax = copyobj(f.R{subjInd,sessInd}(fInd).Children,fAll.R{i});
%             ax.Position = pos{(sessInd-1)*size(d,1)+subjInd};
%             ax.Colormap = f.R{subjInd,sessInd}(fInd).Children.Colormap;
%             drawnow
% %             delete(f{subjInd,sessInd}(fInd).Children);
%         end
%     end
%     suptitle(supTitleList{i})
end





%% Functionaly defined feature selection
for sessInd = 1:size(d,2)
    for subjInd = 1:size(d,1)
        p.subjInd = subjInd;
        p.sessInd = sessInd;
        disp(['subj' num2str(subjInd) '; sess' num2str(sessInd)])
        [featSel{subjInd,sessInd},f{subjInd,sessInd}] = getFeatSel(d{subjInd,sessInd},p);
    end
end
% single hemispheres








indInX = cell(1,size(d,2));
dX = cell(1,size(d,2));
fieldList = fields(d{subjInd,sessInd});
for sessInd = 1:size(d,2)
    for subjInd = 1:size(d,1)
        if subjInd==1
            indInX{sessInd} = featSel{subjInd,sessInd}.featSeq.featIndIn;
            dX{sessInd} = d{subjInd,sessInd};
        else
            indInX{sessInd} = cat(1,indInX{sessInd},featSel{subjInd,sessInd}.featSeq.featIndIn);
            for fieldInd = 1:length(fieldList)
                if isnumeric(d{subjInd,sessInd}.(fieldList{fieldInd}))...
                        && ~strcmp(fieldList{fieldInd},'sinDesign')...
                        && ~strcmp(fieldList{fieldInd},'hrDesign')
                    dX{sessInd}.(fieldList{fieldInd}) = cat(1,mean(dX{sessInd}.(fieldList{fieldInd}),4),mean(d{subjInd,sessInd}.(fieldList{fieldInd}),4));
                elseif isstruct(d{subjInd,sessInd}.(fieldList{fieldInd}))...
                        && ~strcmp(fieldList{fieldInd},'featSel')
                    fieldList2 = fields(d{subjInd,sessInd}.(fieldList{fieldInd}));
                    for fieldInd2 = 1:length(fieldList2)
                        if isnumeric(d{subjInd,sessInd}.(fieldList{fieldInd}).(fieldList2{fieldInd2}))...
                                || islogical(d{subjInd,sessInd}.(fieldList{fieldInd}).(fieldList2{fieldInd2}))
                            dX{sessInd}.(fieldList{fieldInd}).(fieldList2{fieldInd2}) = ...
                                cat(1,dX{sessInd}.(fieldList{fieldInd}).(fieldList2{fieldInd2}),d{subjInd,sessInd}.(fieldList{fieldInd}).(fieldList2{fieldInd2}));    
                        end
                    end
                end
            end
        end
    end
end

sessInd = 1;
plotVoxOnFoV(dX{sessInd},p,true(size(dX{sessInd}.sin,1),1))
ax = gca;
RLim = ax.RLim;
title('allVox')
for featInd = 1:length(featSel{subjInd,sessInd}.featSeq.featSelList)
    plotVoxOnFoV(dX{sessInd},p,indInX{sessInd}(:,featInd,1))
    title(featSel{subjInd,sessInd}.featSeq.featSelList{featInd})
    ax = gca;
    ax.RLim = RLim;
end

featSel{subjInd,sessInd}.featSeq.featSelList'
featInd = [3 4];
plotVoxOnFoV(dX{sessInd},p,all(indInX{sessInd}(:,featInd,1),2))
ax = gca;
R = [ax.Children(3).RData ax.Children(4).RData];
figure('WindowStyle','docked');
R = exp(R)-1;
hist(R,100)




featInd = [0];
condPairInd = 1;
if featInd==0
    ind = true(size(featSel{subjInd,sessInd}.featSeq.featIndIn,1),1);
else
    ind = all(featSel{subjInd,sessInd}.featSeq.featIndIn(:,featInd,condPairInd),2);
end
p.featSel.fov.threshVal = [];
plotVoxOnFoV(dX{1},p,ind)

% fac = 1;
% fac = (2*pi);
% fac = 1/(2*pi);
% fac = (2*2*pi);
fac = 1/(2*2*pi);

R = dX{sessInd}.voxProp.ecc;
Rp = cdf(nonparamDistFit(R),R);
v = linspace(min(R),max(R)*fac,length(unique(R)));%R
x = linspace(1/length(unique(R)),1,length(unique(R)));%Rp
xq = Rp;%Rp
vq = interp1(x,v,xq);%R
R2 = vq;
Rp2 = xq;
figure('WindowStyle','docked');
[~,uInd,~] = unique(R);
plot(R(uInd),Rp(uInd),'.'); hold on
[~,uInd,~] = unique(R2);
plot(R2(uInd),Rp2(uInd),'.'); hold on
nonparamDistFit(R2,0)

d2 = dX{sessInd};
d2.voxProp.ecc = R2;
plotVoxOnFoV(d2,p,ind)





%% Save
disp('saving feature selection')
if ~exist(fullfile(funPath,outDir),'dir')
    mkdir(fullfile(funPath,outDir))
end
fullfilename = fullfile(funPath,outDir,'featSel.mat');
save(fullfilename,'featSel')
disp(['saved to: ' fullfilename])
