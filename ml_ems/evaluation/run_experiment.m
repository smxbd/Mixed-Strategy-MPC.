function out=run_experiment(varargin)
%RUN_EXPERIMENT Unified entry point for closed-loop and lightweight runs.
% Supported forms: (cycleStruct,controllerHandle,opts) and (cfg,cycle,method,seed).
if nargin==4 && isstruct(varargin{1}) && (ischar(varargin{2}) || isstring(varargin{2}) || isstruct(varargin{2}))
    out=run_continuation_experiment(varargin{1},varargin{2},varargin{3},varargin{4}); return
end
if nargin~=3, error('EMS:run_experiment:InvalidSignature','Use (cycle,controller,opts) or (cfg,cycle,method,seed).'); end
cycle=varargin{1}; controller=varargin{2}; opts=varargin{3};
if ~isstruct(cycle) || ~isa(controller,'function_handle') || ~isstruct(opts), error('EMS:run_experiment:InvalidSignature','Legacy form requires (struct,function_handle,struct).'); end
N=numel(cycle.time); u=zeros(N,4); timer=tic; state=struct('soc',opts.initial_soc);
for k=1:N, u(k,:)=controller(cycle,k,state); end
elapsed=toc(timer);
out=struct('status','completed','cycle',cycle.name,'u',u,'mean_compute_time',elapsed/max(N,1),'time',cycle.time,'v_ref',cycle.v_ref);
end
