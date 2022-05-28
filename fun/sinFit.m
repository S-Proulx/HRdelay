function [fitresult, gof] = sinFit(t, y)
%CREATEFIT(T,Y)
%  Create a fit.
%
%  Data for 'untitled fit 1' fit:
%      X Input : t
%      Y Output: y
%  Output:
%      fitresult : a fit object representing the fit.
%      gof : structure with goodness-of fit info.
%
%  See also FIT, CFIT, SFIT.

%  Auto-generated by MATLAB on 19-Jan-2021 21:43:03


%% Fit: 'untitled fit 1'.
[xData, yData] = prepareCurveData( t, y );

% Set up fittype and options.
ft = fittype( 'a*sin(-(1/(12/pi/2))*(x+c))+b', 'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [0.198596507418309 0.757097784791743 0];

% Fit model to data.
[fitresult, gof] = fit( xData, yData, ft, opts );

% % Plot fit with data.
% figure( 'Name', 'untitled fit 1' );
% h = plot( fitresult, xData, yData );
% legend( h, 'y vs. t', 'untitled fit 1', 'Location', 'NorthEast', 'Interpreter', 'none' );
% % Label axes
% xlabel( 't', 'Interpreter', 'none' );
% ylabel( 'y', 'Interpreter', 'none' );
% grid on

