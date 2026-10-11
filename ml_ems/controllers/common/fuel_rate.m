function mdot=fuel_rate(ne,te,p)
ne0=min(max(ne,p.ne_map(1)),p.ne_map(end)); te0=min(max(te,0),p.Te_map(end));
bsfc=interp2(p.ne_map,p.Te_map,p.fuel_map,ne0,te0,'linear');
mdot=bsfc.*max(0,ne.*te/9549)/3600; % g/s, consistent with original BSFC path
end
