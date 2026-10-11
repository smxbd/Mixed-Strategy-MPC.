function out=init_transmission_params(input)
% Pure extraction of original numerical parameters; no file writes or figures.
names=fieldnames(input); for kk=1:numel(names), eval([names{kk} '=input.(names{kk});']); end
iq=30/36*42/25;kq=2.17;Yq=0.94;
k1=2.13;k2=2.13;k3=2.33;k4=1.92;Yo=0.92;
kh=2.88;kt=1.83;it=4.0;ic=4.42;Yh=0.96;Yc=0.98;
Jq1=1e-2;Jq2=1e-2;Jh=1e-2;
Js123=1e-2;Jr1=1e-2;Jc1r2=1e-2;
Jr3s4=1e-2;Jc3r4=1e-2;Jc4=1e-2;
Tmax_C0=max(Te_max_map);SF_C0=1.5;TS_C0=0.2;
Tmax_ZD=Tmax_C0*iq;SF_ZD=1.5;TS_ZD=0.2;
Tmax_Z1=k3*((1+k1+k2)/k1/k2*max(TA_max_map)+max(TB_max_map));SF_Z1=1.5;TS_Z1=0.2;
Tmax_Z2=(1+k4)*Tmax_Z1;SF_Z2=1.5;TS_Z2=0.2;
Tmax_C1=k2/(1+k2)*max(Te_max_map)+(1+k1)/k1*max(TA_max_map);SF_C1=1.5;TS_C1=0.2;
Tmax_C2=k2/(1+k2)*max(Te_max_map)+(1+k1)/k1*max(TA_max_map);SF_C2=1.5;TS_C2=0.2;
a11=(1+k1)*(1+k2)/k1/k2/iq;a12=-(1+k1+k2)*(1+k3)/k1/k2;
a11_L=a11;a12_L=a11*(1+k3+k4)/(1+k3);
b11=0;b12=(1+k3);
b11_L=0;b12_L=(1+k3+k3*k4);
a21=-(1+k2)/k1/iq;a22=(1+k1+k2)/k1;
b21=(1+k2)/iq;b22=-k2;
c11=-k1*k2/(1+k1)/(1+k2)*iq;c12=0;
d11=-(1+k1+k2)/(1+k1)/(1+k2)*iq;d12=1/(1+k3);
c21=-k1*k2/(1+k1)/(1+k2)*iq;c22=k1/(1+k1);
d21=-(1+k1+k2)/(1+k1)/(1+k2)*iq;d22=1/(1+k1);
e11=d12/(c11*d12-c12*d11);e12=-c12/(c11*d12-c12*d11);
f11=-d11/(c11*d12-c12*d11);f12=c11/(c11*d12-c12*d11);
e21=d22/(c21*d22-c22*d21);e22=-c22/(c21*d22-c22*d21);
f21=-d21/(c21*d22-c22*d21);f22=c21/(c21*d22-c22*d21);

names=who; out=struct; for kk=1:numel(names), if ~ismember(names{kk},{'out','names','kk','input'}), out.(names{kk})=eval(names{kk}); end, end
end
