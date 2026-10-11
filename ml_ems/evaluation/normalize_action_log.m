function actions=normalize_action_log(log)
values=log.signals.values; n=numel(log.time);
if isequal(size(values),[n 4])
    actions=values;
elseif size(values,1)==1 && size(values,2)==4 && size(values,3)==n
    actions=reshape(permute(values,[3 2 1]),n,4);
else
    error('EMS:ActionShape','Unexpected action log dimensions: %s',mat2str(size(values)));
end
assert(all(isfinite(actions),'all'),'EMS:ActionFinite','Actions contain NaN/Inf.');
end
