function f=observation_features(x,o,cfg)
% Causal demand proxy INCLUDING auxiliary load, excluding fixed PN0.
% PN_com is the original battery request minus PN0 and auxiliary load.
% This is a control-demand proxy, not measured wheel propulsion power.
demand=x(1)+x(15)+o(9);
f=[o(1) demand o(9) o(10) o(2) o(3)/100 o(11) x(2)];
if ~all(isfinite(f)), error('EMS:Observation','Nonfinite observation'); end
end
