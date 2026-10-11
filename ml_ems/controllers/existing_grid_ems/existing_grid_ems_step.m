function [u,meta] = existing_grid_ems_step(x,legacyFcn)
%EXISTING_GRID_EMS_STEP Adapter for the original 19-input MATLAB Function.
% x.u19 must preserve the original input ordering.
if nargin<2 || isempty(legacyFcn), legacyFcn=@(z) [z(5),0,0,0]; end
assert(isfield(x,'u19') && numel(x.u19)==19,'Expected original 19-element input vector.');
u=legacyFcn(double(x.u19(:))); u=double(u(:).'); assert(numel(u)==4,'Controller must return four references.');
meta=struct('controller_name','Existing heuristic-grid EMS','fallback_flag',false,'raw_action',u,'safe_action',u);
end
