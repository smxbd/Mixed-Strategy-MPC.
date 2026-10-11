function out=init_legacy_controller_params(input)
% Pure extraction of original numerical parameters; no file writes or figures.
names=fieldnames(input); for kk=1:numel(names), eval([names{kk} '=input.(names{kk});']); end
V_Start=10;
ne_start=200;
nB_start=0;
V_Shift12=32;
V_Shift21=25;
no_Shift12=V_Shift12*ic*(1+kh)/0.377/kh/rz;
no_Shift21=V_Shift21*ic*(1+kh)/0.377/kh/rz;
C0_shift=200;
C1_shift=200;
C2_shift=200;
Z1_shift=200;
Z2_shift=200;
SOC_epr=[30 31 50 59 60 61 70 79 80];
Pb_epr=[-45 -45 -40 -30 0 30 40 45 45];
PN0=0;
Voltage_epr=[750 760 900 1000 1050];
Pb_min=[-45 -45 -45 -40 0];
Pb_max=[0 40 45 45 45];

names=who; out=struct; for kk=1:numel(names), if ~ismember(names{kk},{'out','names','kk','input'}), out.(names{kk})=eval(names{kk}); end, end
end
