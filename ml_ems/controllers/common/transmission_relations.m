function [M,n]=transmission_relations(x,p)
if x(4)==3
 M=[p.e21 p.e22;p.f21 p.f22]; n=[p.a21*x(5)+p.a22*x(8),p.b21*x(5)+p.b22*x(8)];
else
 M=[p.e11 p.e12;p.f11 p.f12]; n=[p.a11*x(5)+p.a12*x(8),p.b11*x(5)+p.b12*x(8)];
end
if x(3)~=1, M=M/p.kq; end
% Ideal kinematic reaction. Apply actuator/gear losses in engine_load_relation.
end
