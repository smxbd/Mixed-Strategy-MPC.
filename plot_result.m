close all;clc;
% load result_backup.mat
load result.mat
figure;
plot(v_com_act_Td.time,v_com_act_Td.signals(1,1).values,'-r','LineWidth',2);
hold on;plot(v_com_act_Td.time,v_com_act_Td.signals(1,2).values,'-b','LineWidth',2);
xlabel('仿真时间/s');ylabel('车速/kmph');
legend('目标车速','实际车速');
figure;
plot(stage_acc_dec.time,stage_acc_dec.signals(1,2).values*100,'-b','LineWidth',2);
hold on;plot(stage_acc_dec.time,-stage_acc_dec.signals(1,3).values*100,'-g','LineWidth',2);
xlabel('仿真时间/s');ylabel('踏板开度信号/%');legend('加速踏板开度','制动踏板开度');
figure;
plot(v_com_act_Td.time,v_com_act_Td.signals(1,3).values,'-b','LineWidth',2);
xlabel('仿真时间/s');ylabel('驱动转矩/Nm');
figure;
plot(engine_swith_ne_Te_Pe.time,engine_swith_ne_Te_Pe.signals(1,2).values,'-r','LineWidth',2);
hold on;plot(nA_TA_PA.time,nA_TA_PA.signals(1,1).values,'--g','LineWidth',2);
plot(nB_TB_PB.time,nB_TB_PB.signals(1,1).values,'-.b','LineWidth',2);
xlabel('仿真时间/s');ylabel('各元件转速/(rpmin)');legend('发动机','电机A','电机B');
figure;
plot(engine_swith_ne_Te_Pe.time,engine_swith_ne_Te_Pe.signals(1,3).values,'-r','LineWidth',2);
hold on;plot(nA_TA_PA.time,nA_TA_PA.signals(1,2).values,'--g','LineWidth',2);
plot(nB_TB_PB.time,nB_TB_PB.signals(1,2).values,'-.b','LineWidth',2);
xlabel('仿真时间/s');ylabel('各元件转矩/(Nm)');legend('发动机','电机A','电机B');
figure;
plot(engine_swith_ne_Te_Pe.time,engine_swith_ne_Te_Pe.signals(1,4).values,'-r','LineWidth',2);
hold on;plot(nA_TA_PA.time,nA_TA_PA.signals(1,3).values,'--g','LineWidth',2);
plot(nB_TB_PB.time,nB_TB_PB.signals(1,3).values,'-.b','LineWidth',2);
plot(battery.time,battery.signals(1,4).values,'-.k','LineWidth',2);
xlabel('仿真时间/s');ylabel('各元件功率/kW');legend('发动机','电机A','电机B','电池组');

%电机工作点
N=length(v_com_act_Td.time);
nA=nA_TA_PA.signals(1,1).values;
TA=nA_TA_PA.signals(1,2).values;
figure;subplot(1,2,1);
% nAp=nA;TAp=TA;
nAp=zeros(1,1000);TAp=zeros(1,1000);
for x=1:1000
    nAp(x)=nA(fix((N-1)/1000)*(x-1)+1);
    TAp(x)=TA(fix((N-1)/1000)*(x-1)+1);
end
nA_map=[-7000:50:-3250 -3200 0 3200 3250:50:7000];
TA_max_map=[370*9549./(7000:-50:3250) 1100 1100 1100 370*9549./(3250:50:7000)];
plot(nA_map,TA_max_map,'k','LineWidth',2.5);
hold on;plot(nA_map,-TA_max_map,'k','LineWidth',2.5);
plot(nAp,TAp,'*');axis([-6500 6500 -1200 1200]);
xlabel('电机A转速/rpm');ylabel('电机A转矩/Nm');
title('电机A工作点分布');

nB=nB_TB_PB.signals(1,1).values;
TB=nB_TB_PB.signals(1,2).values;
subplot(1,2,2);
% nBp=nB;TBp=TB;
nBp=zeros(1,1000);TBp=zeros(1,1000);
for x=1:1000
    nBp(x)=nB(fix((N-1)/1000)*(x-1)+1);
    TBp(x)=TB(fix((N-1)/1000)*(x-1)+1);
end
nB_map=[-7000:50:-3250 -3200 0 3200 3250:50:7000];
TB_max_map=[370*9549./(7000:-50:3250) 1110 1110 1110 370*9549./(3250:50:7000)];
plot(nB_map,TB_max_map,'k','LineWidth',2.5);
hold on;plot(nB_map,-TB_max_map,'k','LineWidth',2.5);
plot(nBp,TBp,'*');axis([-6500 6500 -1200 1200]);
xlabel('电机B转速/rpm');ylabel('电机B转矩/Nm');
title('电机B工作点分布');

%发动机工作点
ne=engine_swith_ne_Te_Pe.signals(1,2).values;
Te=engine_swith_ne_Te_Pe.signals(1,3).values;
figure;
% nep=ne;Tep=Te;
k=5000;nep=zeros(1,k);Tep=zeros(1,k);
for x=1:k
    nep(x)=ne(fix((N-1)/k)*(x-1)+1);
    Tep(x)=Te(fix((N-1)/k)*(x-1)+1);
end

for i=1:length(nep)
    Temax=interp1(ne_map,Te_max_map,nep(i));
    if Tep(i)>Temax
        Tep(i)=Temax;
    else
    end        
end
[C,h]=contour(ne_map,Te_map,fuel_map_N,[198 199 200 201 202 204 206 208 210 212 213 214 216 220 225 230 235 240 245 250 260 270 300 350 400 500]); 
set(h,'ShowText','on');hold on;
plot(ne_map,Te_max_map,'b','LineWidth',2.0);
% plot(neg,Teg,'r','Linewidth',1.5);
% plot(nep,Tep,'ks','Linewidth',1.5,'MarkerEdgeColor','m','MarkerFaceColor','c','MarkerSize',4);%发动机实际工作点
plot(nep,Tep,'*m');
xlabel('发动机转速/rpm');ylabel('发动机转矩/Nm');
legend('等油耗曲线','外特性曲线','实际工作点');
% legend('等油耗曲线','外特性曲线','经济性曲线','实际工作点');

% close all;
%电力分流功率
figure;
plot(v_com_act_Td.time,nA_TA_PA.signals(1,3).values./engine_swith_ne_Te_Pe.signals(1,4).values,'-g','LineWidth',2);hold on;
plot(v_com_act_Td.time,nB_TB_PB.signals(1,3).values./engine_swith_ne_Te_Pe.signals(1,4).values,'--b','LineWidth',2);
xlabel('仿真时间/s');ylabel('电力分流比例');
legend('PA/Pe','PB/Pe');
% figure;
% plot(v_com_act_Td.signals(1,2).values,nA_TA_PA.signals(1,3).values./engine_swith_ne_Te_Pe.signals(1,4).values,'-g','LineWidth',2);hold on;
% plot(v_com_act_Td.signals(1,2).values,nB_TB_PB.signals(1,3).values./engine_swith_ne_Te_Pe.signals(1,4).values,'--b','LineWidth',2);
% xlabel('实际车速/kmph');ylabel('电力分流比例');
% legend('PA/Pe','PB/Pe');

%机械功率损失
Pi=Pi_Po.signals(1,1).values;
% PA=nA_TA_PA.signals(1,3).values;
% PB=nB_TB_PB.signals(1,3).values;
Po=Pi_Po.signals(1,2).values;
% C0_loss=clutch_loss.signals(1,1).values;
% C1_loss=clutch_loss.signals(1,2).values;
% Z1_loss=clutch_loss.signals(1,3).values;
% Z2_loss=clutch_loss.signals(1,4).values;
% Pm_loss=Pi+PA+PB-Po;%机械功率损失
% PC_loss=C0_loss+C1_loss+Z1_loss+Z2_loss;
% Px_loss=Pm_loss-PC_loss;
figure;
plot(v_com_act_Td.time,Po,'-.m','LineWidth',2);
% % plot(v_com_act_Td.time,Pm_loss,'-.m','LineWidth',2);
% % xlabel('仿真时间/s');ylabel('机械功率损失/kW');
% figure;
% plot(v_com_act_Td.time,C0_loss,'-r','LineWidth',2);hold on;
% plot(v_com_act_Td.time,C1_loss,'-.g','LineWidth',2);
% plot(v_com_act_Td.time,Z1_loss,'--b','LineWidth',2);
% plot(v_com_act_Td.time,Z2_loss,'-.m','LineWidth',2);
% xlabel('仿真时间/s');ylabel('离合器功率损失/kW');
% legend('C0','C1','Z1','Z2');
% figure;
% plot(v_com_act_Td.time,PC_loss,'-.g','LineWidth',2);hold on;
% plot(v_com_act_Td.time,Px_loss,'-b','LineWidth',2);
% xlabel('仿真时间/s');ylabel('机械功率损失分布/kW');
% legend('离合器带排损失','齿轮啮合损失');
% 
% %电力功率损失
% PA_loss=abs(nA_TA_PA.signals(1,3).values-nA_TA_PA.signals(1,4).values);
% PB_loss=abs(nB_TB_PB.signals(1,3).values-nB_TB_PB.signals(1,4).values);
% Pb_loss=abs(battery.signals(1,4).values-ElectricPower.signals.values-14-nA_TA_PA.signals(1,4).values-nB_TB_PB.signals(1,4).values);
% Pele_loss=PA_loss+PB_loss+Pb_loss;%电力功率损失
% figure;
% plot(v_com_act_Td.time,Pele_loss,'--g','LineWidth',2);
% xlabel('仿真时间/s');ylabel('电力功率损失/kW');
% 
% %功率损失
% figure;
% plot(v_com_act_Td.time,Pm_loss,'-.b','LineWidth',2);hold on;
% plot(v_com_act_Td.time,Pele_loss,'--g','LineWidth',2);
% plot(v_com_act_Td.time,Pele_loss+Pm_loss,'-r','LineWidth',2);
% xlabel('仿真时间/s');ylabel('功率损失/kW');
% legend('机械功率损失/kW','电力功率损失/kW','总功率损失/kW');
% % figure;
% % plot(v_com_act_Td.signals(1,2).values,Pm_loss,'-.b','LineWidth',2);hold on;
% % plot(v_com_act_Td.signals(1,2).values,Pele_loss,'--g','LineWidth',2);
% % plot(v_com_act_Td.signals(1,2).values,Pele_loss+Pm_loss,'-r','LineWidth',2);
% % xlabel('实际车速/kmph');ylabel('功率损失/kW');
% % legend('机械功率损失/kW','电力功率损失/kW','总功率损失/kW');
% 
% %传动效率
figure;
Y=Po./Pi;
plot(v_com_act_Td.time,100*Y,'-.b','LineWidth',2);
xlabel('仿真时间/s');ylabel('传动效率/%');
axis([0 200 0 100]);
% % figure;
% % Y=Po./Pi;
% % plot(v_com_act_Td.signals(1,2).values,100*Y,'-b','LineWidth',2);
% % xlabel('实际车速/kmph');ylabel('传动效率/%');



