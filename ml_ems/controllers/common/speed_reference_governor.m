function g=speed_reference_governor(c,p)
% Preview governor at DRIVER input; does not pretend the EMS can shift/brake.
% High-mode A bound robust over the original commanded engine-speed domain.
roadPerKmh=(1+p.kh)/p.kh*p.ic/.377/p.rz;
cap=(p.nA_max-p.a21*p.ne_min)/p.a22/roadPerKmh;
g=struct('time',c.time(:),'requested_kmh',c.v_ref(:), ...
 'safe_kmh',min(c.v_ref(:),cap),'cap_kmh',cap, ...
 'reason','EVT2 Motor A kinematics over original engine reference domain', ...
 'hard_safety_certified',false,'new_interface','driver lookup SID 22002 Table override');
% This is an input governor, not a guarantee that actual speed tracks its
% target or actual ne remains in its reference domain. Both must be measured.
end
