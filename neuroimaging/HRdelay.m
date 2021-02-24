clear all
%% Dependencies
addpath(genpath(fullfile(pwd,'matlabFun')));
verbose = 1; % prints more info

%% Between-session feature selection parameters
% Activated voxels
featSel_bSess.activation.doIt = 1;
featSel_bSess.activation.fitType = 'fixed';
featSel_bSess.activation.threshType = 'p';
featSel_bSess.activation.threshVal = 0.05;
% Vein voxels
featSel_bSess.vein.doIt = 1;
featSel_bSess.vein.source = 'fullModelResid';% 'reducedModelResid' (stimulus-driven signal included in std) or 'fullModelResid (stimulus-driven signal excluded in std)'
featSel_bSess.vein.percentile = 20;
% Discriminant voxels
featSel_bSess.discrim.doIt = 1;
featSel_bSess.discrim.percentile = 20;
%% Display parameters
figOption.save = 0; % save all figures
figOption.subj = 1; % subjInd-> plots participants subjInd; +inf-> plots all participant (if verbose==0, will only plot subjInd==1 but still produce and save all the other figures)

importData(verbose)
applyAreaMask(figOption)

% runFit(verbose,figOption)
runFit2(verbose,figOption)
runWave2(verbose,figOption)

preprocAndShowMasks(featSel_bSess,figOption,verbose)
inspectSubjAndExclude(figOption,verbose)



runGroupAnalysis_sin(figOption,verbose)
runGroupAnalysis_hr(figOption,verbose)

verbose = 1; % prints more info
res = runAllDecoding(figOption,verbose);

return
runAllDecodingPerm(res,figOption,verbose);
