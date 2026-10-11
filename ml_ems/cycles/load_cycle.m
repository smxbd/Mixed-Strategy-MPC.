function cycle=load_cycle(name,cycle_dir)
if nargin<2||isempty(cycle_dir), cycle_dir=fileparts(mfilename('fullpath')); end; f=fullfile(cycle_dir,[char(name) '.mat']); if exist(f,'file'), s=load(f,'cycle'); cycle=s.cycle; return; end
switch lower(char(name)), case 'city200', cycle=build_city200(); case 'suburban400', cycle=build_suburban400(); case 'stress300', cycle=build_stress300(); otherwise, error('Unknown cycle: %s',name); end
end
