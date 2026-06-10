function A = fitCST(x,y,N)

C = sqrt(x).*(1-x);

M = zeros(length(x),N);

for i=0:N-1

    K = nchoosek(N-1,i);

    M(:,i+1)=C.*K.*x.^i.*(1-x).^(N-1-i);

end

valid = C>1e-8;

A = M(valid,:)\y(valid);

A = A';

end