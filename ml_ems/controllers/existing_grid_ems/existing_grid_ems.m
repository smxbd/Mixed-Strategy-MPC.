function y = existing_grid_ems(u)
%#codegen
Pe_com=u(1);pedal=u(2);ZD=u(3);stage=u(4);ne_act=u(5);ne_max=u(6);ne_min=u(7);
no_act=u(8);Te_max=u(9);Te_min=u(10);TA_max=u(11);TA_min=u(12);TB_max=u(13);
TB_min=u(14);PN_com=u(15);PN_max=u(16);PN_min=u(17);PZ_com=u(18);sd_ne=u(19);
%转速转矩关系
a11=1.5424;a12=-3.8607;%EVT1模式下nA表达式的系数nA=a11*ne+a12*no
a11_L=1.5424;a12_L=2.4317;%EVT1_L模式下nA表达式的系数nA=a11_L*ne+a12_L*no
b11=0;b12=3.3300;%EVT1模式下nB表达式的系数nB=b11*ne+b12*no
b11_L=0;b12_L=7.8036;%EVT1模式下nB表达式的系数nB=b11*ne+b12*no
a21=-1.0496;a22=2.4695;%EVT2模式下nA表达式的系数nA=a21*ne+a22*no
b21=2.2357;b22=-2.1300;%EVT2模式下nB表达式的系数nB=b21*ne+b22*no
e11=-1.5424;e12=0;%EVT1模式下Te表达式的系数Te=e11*TA+e12*TB
f11=-3.8607;f12=3.3300;%EVT1模式下To表达式的系数To=f11*TA+f12*TB
e21=1.0496;e22=-2.2357;%EVT2模式下Te表达式的系数Te=e21*TA+e22*TB
f21=2.4695;f22=-2.1300;%EVT2模式下To表达式的系数To=f21*TA+f22*TB
kq=2.17;YE=0.75;YA=0.8;YB=0.8;%平均效率
if pedal>0.99&&no_act<49.67*50
    TA_max=1.5*TA_max;TA_min=1.5*TA_min;
    TB_max=1.5*TB_max;TB_min=1.5*TB_min;
else
end
if stage<3
    nA=a11*ne_act+a12*no_act;
    nB=b11*ne_act+b12*no_act;
elseif stage<4
    nA=a21*ne_act+a22*no_act;
    nB=b21*ne_act+b22*no_act;
else
    nA=a11_L*ne_act+a12_L*no_act;
    nB=b11_L*ne_act+b12_L*no_act;
end
%发动机燃油经济性曲线
Peg=[0,100,120,140,160,180,200,220,240,260,280,300,320,340,360,380,400,420,440,460,480,500,520,540,560,580,600,620,640,660,680,700,720,740,760,780,800,820,840,860,880,900,920,940,960,980,1000,1020,1040,1060,1080,1100,1200];
neg=[1600,1600,1800,1860,1910,2000,2001,2200,2300,2301,2400,2450,2610,2611,2612,2613,2700,2701,2702,2730,2790,2880,2900,2901,2902,2903,3200,3201,3202,3203,3204,3205,3206,3207,3300,3301,3302,3310,3350,3390,3420,3500,3501,3700,3701,3702,3760,3761,3810,4180,4200,4200,4200];
Pe_com=min(Pe_com,max(Peg));
Pe_com=max(Pe_com,min(Peg));
ne_ref=interp1(Peg,neg,Pe_com);
ne_idl=3000;%发动机启动转速
V_Shift12=32;%EVT1到EVT2的换段车速(km/h)
V_Shift21=25;%EVT2到EVT1的换段车速(km/h)
alpha=max(pedal,0);
V_Shift12=V_Shift12-5*(1-alpha);
V_Shift21=V_Shift21+5*alpha;
if stage<3&&no_act>49.67*(V_Shift12-2)
    ne_ref=max(2.442*no_act,ne_ref);
elseif stage>1&&no_act<49.67*(V_Shift21+2)
    ne_ref=min(2.442*no_act,ne_ref);
elseif pedal<0
    ne_ref=2.442*no_act;   
else
end
if pedal>0.8&&ne_max<4200&&no_act<49.67*10
    ne_max=ne_max-500;
else
end
ne_min=max(ne_idl,ne_min);ne_max=min(4200,ne_max);
ne_min=max(ne_act-100,ne_min);ne_max=min(ne_act+500,ne_max);
ne_ref=max(ne_ref,ne_min);ne_ref=min(ne_ref,ne_max);
ne_ref0=ne_ref;
if pedal>0
    ne_ref=ne_ref+sd_ne;
else
end
% x_ne=[-500 -200 -100 -50 0 50 100 200 500];
% x_Te=[0.1 0.2 0.5 0.8 1 1.5 2.0 5.0 10];
x_ne=[-200 0 200];
x_Te=[0.6 1 2.0];
dne=ne_ref-ne_act;dne=min(dne,200);dne=max(dne,-200);
x_ne=interp1(x_ne,x_Te,dne);
if ne_act==0
    Te_ref=Te_max;
else
    Te_ref=9549*Pe_com/ne_act;
end
Te_ref=max(Te_ref,200);
Te_ref=x_ne*Te_ref;
Te_ref=max(Te_ref,Te_min);Te_ref=min(Te_ref,Te_max);
Te1=linspace(Te_ref,Te_min,10);Te2=linspace(Te_ref,Te_max,10);
Te=[Te1 Te2];L_Te=length(Te);
TA=linspace(TA_min,TA_max,20);L_TA=length(TA);
TB=linspace(TB_min,TB_max,20);L_TB=length(TB);
TA0=zeros(1,L_TA*L_TB);TB0=zeros(1,L_TA*L_TB);
for i=1:L_TA
    for j=1:L_TB
        TA0((j-1)*L_TA+i)=TA(i);
        TB0((j-1)*L_TA+i)=TB(j);
    end
end
TA=TA0;TB=TB0;
if ZD==1
    if stage==3
        Tef=(e21.*TA+e22.*TB);
        To=(f21.*TA+f22.*TB);
    else
        Tef=(e11.*TA+e12.*TB);
        To=(f11.*TA+f12.*TB);
    end
else
    if stage==3
        Tef=(e21.*TA+e22.*TB)/kq;
        To=(f21.*TA+f22.*TB)/kq;
    else
        Tef=(e11.*TA+e12.*TB)/kq;
        To=(f11.*TA+f12.*TB)/kq;
    end
end
Tef=Tef*YE;
PA=TA*nA/9549;PB=TB*nB/9549;
PN=PA.*YA.^sign(-PA)+PB.*YB.^sign(-PB);
PN_com=PN_com-PZ_com;
TA_ref=0;TB_ref=0;
J0=1e10;NN_Te=0;
NN_ne=zeros(L_Te,L_TA*L_TB);
NN_PN0=zeros(L_Te,L_TA*L_TB);
NN_PN1=zeros(L_Te,L_TA*L_TB);
for i=1:L_Te    
    for j=1:L_TA*L_TB
        if (PN(j)<3*PN_min&&PN(j)-PN_com<3*PN_min)||(PN(j)>3*PN_max&&PN(j)-PN_com>3*PN_max)
            continue;
        else
        end
        NN_PN0(i,j)=1;         
        if dne>10
            if Tef(j)*x_ne>Te(i)
                continue;
            else
            end     
        elseif dne<-10
            if Tef(j)*x_ne<Te(i)
                continue;
            else
            end
        else
        end
        NN_ne(i,j)=1;
        if PN(j)-PN_com<3*PN_min||PN(j)-PN_com>3*PN_max
            continue;
        else
        end
        NN_PN1(i,j)=1;
        if PN(j)-PN_com<PN_min||PN(j)-PN_com>PN_max
            continue;
        else
        end
        if PN_com>0
            if PN(j)<0
                continue;
            else
            end
        elseif PN_com<0 
            if PN(j)>0
                continue;
            else
            end
        else
        end
        if pedal>=0.9
            J1=0;
        elseif pedal<=0
            J1=PN(i);
        else
            J1=abs(PN(j)-PN_com);
        end
        if pedal<=0
            J2=0;
        else
            J2=-To(j)*ne_ref/9549;
        end
        J=J1+J2;
        if J<J0
            J0=J;
            Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);
            NN_Te=1;
        else
        end
    end
    if NN_Te==1
        break;
    else
    end
    for j=1:L_TA*L_TB
        if NN_PN1(i,j)==0
            continue;
        else
        end
        if pedal>=0.9
            J1=0;
        elseif pedal<=0
            J1=PN(i);
        else
            J1=abs(PN(j)-PN_com);
        end
        if pedal<=0
            J2=0;
        else
            J2=-To(j)*ne_ref/9549;
        end
        J=J1+J2;
        if J<J0
            J0=J;
            Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);
            NN_Te=1;
        else
        end
    end
    if NN_Te==1
        break;
    else
    end
end
if NN_Te==0
    for i=1:L_Te    
        for j=1:L_TA*L_TB
            if NN_ne(i,j)==0
                continue;
            else
            end
            if PN_com<0
                if PN(j)-PN_com>3*PN_max
                    continue;
                else
                end
                J1=PN(j);
            else
                if PN(j)-PN_com<3*PN_min
                    continue;
                else
                end
                J1=-PN(j);
            end
            if pedal<=0
                J2=0;
            else
                J2=-To(j)*ne_ref/9549;
            end
            J=100*J1+J2;
            if J<J0
                J0=J;
                Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);

            else
            end 
        end
    end
else
end
if NN_Te==0
    if ne_ref>ne_act
        Te_ref=Te_max;
    else
        Te_ref=Te_min;
    end
    for j=1:L_TA*L_TB
        if  NN_PN0(i,j)==0
            continue;
        else
        end
        if ne_ref>ne_act
            J1=Tef(j);
        else
            J1=-Tef(j);
        end
        if pedal<=0
            J2=0;
        else
            J2=-To(j);
        end
        J=100*J1+J2;
        if J<J0
            J0=J;
            Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);
            NN_Te=1;
        else
        end 
    end
else
end
if NN_Te==0
    for i=1:L_Te    
        for j=1:L_TA*L_TB
            if dne>10
                if Tef(j)*x_ne>Te(i)
                    continue;
                else
                end     
            elseif dne<-10
                if Tef(j)*x_ne<Te(i)
                    continue;
                else
                end
            else
            end
            if PN(j)<PN_min
                J1=-PN(j);
            elseif PN(j)>PN_max
                J1=PN(j);
            else
                J1=abs(PN(j)-PN_com);
            end            
            if pedal<=0
                J2=0;
            else
                J2=-To(j)*ne_ref/9549;
            end
            if ne_ref>ne_act
                J3=Tef(j)*ne_ref/9549;
            else
                J3=-Tef(j)*ne_ref/9549;
            end
            J=J1+J2+100*J3;
            if J<J0
                J0=J;
                Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);
                NN_Te=1;
            else
            end 
        end
    end
else
end
if NN_Te==0
    if ne_ref>ne_act
        Te_ref=Te_max;
    else
        Te_ref=Te_min;
    end
    for j=1:L_TA*L_TB
        if PN(j)<3*PN_min&&PN(j)-PN_com<3*PN_min
            J1=-PN(j);
        elseif PN(j)>3*PN_max&&PN(j)-PN_com>3*PN_max
            J1=PN(j);
        else
            J1=abs(PN(j)-PN_com);
        end            
        if pedal<=0
            J2=0;
        else
            J2=-To(j)*ne_ref/9549;
        end
        J=100*J1+J2;
        if J<J0
            J0=J;
            Te_ref=Te(i);TA_ref=TA(j);TB_ref=TB(j);
        else
        end 
    end
else
end
ne_ref=ne_ref0;
y=[ne_ref Te_ref TA_ref TB_ref];
