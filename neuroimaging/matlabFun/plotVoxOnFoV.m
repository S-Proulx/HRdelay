function plotVoxOnFoV(d,ind,eccRef,flatFlag)
if ~exist('ind','var') || isempty(ind)
    ind = true(size(d.sin,1),1);
end
if ~exist('eccRef','var')
    eccRef = [];
end
if ~exist('flatFlag','var')
    flatFlag = 0;
elseif isa(flatFlag,'cfit')
    flatTrans = flatFlag;
    flatFlag = 1;
elseif flatFlag
    flatTrans = d.voxProp.eccTrans;
end

vec = mean(d.sin(ind,:),2);
[vec,~] = polarSpaceNormalization(vec,'cartRoi');
%         plotDensity(vec)
vec = abs(angle(vec));

cMap = redblue(256);
vecSpace = linspace(pi,0,256);
c = interp1(vecSpace,cMap,vec,'nearest');

figure('WindowStyle','docked');
ecc = d.voxProp.ecc(ind);
if flatFlag
    ecc = flatTrans(ecc);
end
pol = d.voxProp.pol(ind)./180*pi;
hemiL = logical(d.voxProp.hemifieldL(ind));
if any(hemiL)
    polarscatter(pol(hemiL),ecc(hemiL),eps,c(hemiL,:),'.'); hold on
end
hemiR = logical(d.voxProp.hemifieldR(ind));
if any(hemiR)
    polarscatter(-pol(hemiR),ecc(hemiR),eps,c(hemiR,:),'.'); hold on
end
ax = gca;
ax.ThetaZeroLocation = 'top';


if ~isempty(eccRef)
    th = repmat(linspace(0,2*pi,50),[2 1])';
    if flatFlag
        r = flatTrans(eccRef)';
    else
        r = eccRef';
    end
    polarplot(th,r+zeros(size(th)),'k');
end

if flatFlag
    ax = gca;
    ticks = 0:1:eccRef(2);
    ax.RTick = flatTrans(ticks);
    tickLabels = cellstr(num2str(ticks'));
    tickLabels(9:end) = {''};
    ax.RTickLabel = tickLabels;
end



