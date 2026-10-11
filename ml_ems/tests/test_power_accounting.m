function test_power_accounting
% 200 kW propulsion + 10 kW auxiliary + 5 kW fixed = 190 engine + 25 battery.
f=[30 210 10 .045];
[battery,propulsion]=demand_power_balance(f,190,25,5);
assert(abs(battery-25)<1e-12&&abs(propulsion-200)<1e-12);
% Ten extra auxiliary kW require ten extra battery kW, no propulsion change.
[battery2,propulsion2]=demand_power_balance(f+[0 10 10 0],190,35,5);
assert(abs(battery2-battery-10)<1e-12&&abs(propulsion2-propulsion)<1e-12);
% A constrained battery must reduce available propulsion by the energy deficit.
[~,limited]=demand_power_balance(f,190,15,5); assert(abs(limited-190)<1e-12);
disp('Power accounting tests passed: auxiliary counted once and energy deficit retained.');
end
