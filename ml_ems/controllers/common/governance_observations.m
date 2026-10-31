function g=governance_observations(c,p,physical)
% Retain ORIGINAL requested reference in all tracking/distance metrics.
g=speed_reference_governor(c,p);t=physical.time(:);dt=diff(t);
requested=interp1(c.time,c.v_ref,t,'linear');filtered=zeros(size(t));
% Exact first-order driver prefilter for piecewise-linear cycle input.
for k=1:numel(dt)
 alpha=exp(-dt(k));slope=(requested(k+1)-requested(k))/dt(k);
 filtered(k+1)=alpha*filtered(k)+(1-alpha)*requested(k)+slope*(dt(k)-1+alpha);
end
g.physical_time=t;g.requested_reference_kmh=filtered;
g.safe_reference_kmh=physical.signals.values(:,1);
g.reference_reduction_kmh=filtered-g.safe_reference_kmh;
g.active=g.reference_reduction_kmh>1e-6;
end
