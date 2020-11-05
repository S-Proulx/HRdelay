function dataSubj = plotSubj(data,subjInd,sessInd,rLim)

condList = fields(data);
if ~exist('sessInd','var') || isempty(sessInd)
    sessInd = 1:length(data.ori1(subjInd,:));
end
dataSubj = nan(sum(cellfun('length',data.ori1(subjInd,sessInd))),length(condList));

figure('WindowStyle','docked');
for condInd = 1:length(condList)
    dataSubj(:,condInd) = cat(1,data.(condList{condInd}){subjInd,sessInd});
    
    [theta,rho] = cart2pol(real(dataSubj(:,condInd)),imag(dataSubj(:,condInd)));
    h(condInd) = polarplot(theta,rho,'o'); hold on
    [thetaM,rhoM] = cart2pol(real(mean(dataSubj(:,condInd),1)),imag(mean(dataSubj(:,condInd),1)));
    hM(condInd) = polarplot(thetaM,rhoM,'o','Color',h(condInd).Color,'MarkerFaceColor',h(condInd).Color);
end

if exist('rLim','var')
    rlim([0 rLim]);
end
legend(hM',char(condList))
title(['Subject ' num2str(subjInd) '; Sess ' num2str(sessInd)])

