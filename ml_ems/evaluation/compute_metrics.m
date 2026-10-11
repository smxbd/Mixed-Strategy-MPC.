function m=compute_metrics(log,cfg)
if nargin<2||isempty(cfg), cfg=init_controller_params(); end
req={'time','v_ref','v_act','soc','fuel_volume_l'}; for i=1:numel(req), if ~isfield(log,req{i}), log.(req{i})=nan(size(log.time)); end, end
m=struct(); m.fuel_L=log.fuel_volume_l(end); m.delta_soc=log.soc(end)-log.soc(1); m.rmse_kph=sqrt(mean((log.v_ref-log.v_act).^2,'omitnan')); m.distance_km=trapz(log.time,log.v_act/3.6)/1000; m.reference_distance_km=trapz(log.time,log.v_ref/3.6)/1000; m.distance_error_pct=100*abs(m.reference_distance_km-m.distance_km)/max(m.reference_distance_km,eps); m.equivalent_fuel_L=m.fuel_L; if isfield(log,'constraint_violation'), m.constraint_violations=sum(log.constraint_violation(:)>0); else, m.constraint_violations=NaN; end
end
