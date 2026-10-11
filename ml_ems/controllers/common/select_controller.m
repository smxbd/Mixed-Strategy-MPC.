function f = select_controller(controller_id,ctx)
%SELECT_CONTROLLER Return a common four-output controller handle.
switch double(controller_id)
 case 1, f=@(x) existing_grid_ems_step(x,ctx.legacyFcn);
 case 2, f=@(x) ecms_step(x,ctx.vehicle);
 otherwise, error('Controller %g is not implemented in stage C.',controller_id);
end
end
