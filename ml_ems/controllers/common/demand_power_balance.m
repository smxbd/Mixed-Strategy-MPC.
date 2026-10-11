function [requestedBattery,propulsion]=demand_power_balance(feature,enginePower,batteryPower,fixedLoad)
% Feature 2 already includes feature 3 (auxiliary power), but excludes PN0.
requestedBattery=feature(2)+fixedLoad-enginePower;
propulsion=enginePower+batteryPower-feature(3)-fixedLoad;
end
