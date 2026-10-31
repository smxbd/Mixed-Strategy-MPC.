function [mdot,factor]=battery_equivalent_fuel_rate(pb,soc,cfg)
%BATTERY_EQUIVALENT_FUEL_RATE Convert battery power to equivalent fuel rate.
% Positive battery power is discharge. The SOC feedback is shared by CEM and
% ECMS so the optimizer and the baseline use the same energy accounting.
factor=cfg.control.ecms_factor + ...
    cfg.control.ecms_soc_gain.*(cfg.control.soc_target-soc);
factor=max(0,factor);
mdot=factor.*pb*1000/cfg.LHV_kJ_kg; % g/s
end
