function [x,yu,yl] = cstAirfoil(Au,Al,dz,nPts)

x = (1-cos(linspace(0,pi,nPts)'))/2;

N = length(Au)-1;

C = sqrt(x).*(1-x);

Su = zeros(size(x));
Sl = zeros(size(x));

for i=0:N

    K = nchoosek(N,i);

    B = K.*x.^i.*(1-x).^(N-i);

    Su = Su + Au(i+1).*B;
    Sl = Sl + Al(i+1).*B;

end

yu = C.*Su + dz*x;
yl = C.*Sl - dz*x;

end