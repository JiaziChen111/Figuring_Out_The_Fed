function [M,C] = ComItAlg( A,B,Q,R,U,bet,n1,n2,cutoff );
%ComItAlg   Solves for optimization problem in commitment case.
%
%
%  Usage:     [M,C] = ComItAlg( A,B,Q,R,U,bet,n1,n2,cutoff );
%
%  Input:     A        nxn matrix, (n=n1+n2)
%             B        nxk matrix
%             Q        nxn matrix, symmetric
%             R        kxk matrix, symmetric
%             U        nxk matrix
%             bet      scalar, discount factor (eg 0.99)
%             n1       scalar, # of predetermined variables
%             n2       scalar, # of forward looking variables
%             cutoff   scalar, max modulus of backward looking variables
%
%  Output:    M        nxn matrix, [x1(t+1),p2(t+1)] = M*[x1(t),p2(t)] + e(t+1)
%             C        (n2+k+n1)xn matrix, [x2(t),u(t),p1(t)] = C*[x1(t),p2(t)]
%
%
%
%  Details:   Solve for optimization problem in commitment case. The economy
%             evolves as
%
%             x1(t+1)       =   A * x1(t)    + Bu(t) + e(t+1)
%             E(t)x2(t+1)           x2(t)              0
%
%             where x1(t) ("backward looking") has n1 elements,
%             and x2(t) ("forward looking") has n2 elements. The initial
%             value of x1, x1(0), is given by history. Let n=n1+n2.
%             u(t) is an kx1 vector of decision variables, which follows
%             the decision rule.
%
%             Define x(t)=[x1(t),x2(t)]. The loss function of the policy
%             maker is
%
%             Sum{ (bet^t)*[x(t)'Q*x(t)+2x(t)'U*u(t)+u(t)'R*u(t)],t=0,1,... }
%
%
%  Notice:  Updated version, uses the new built-in function ordqz
%
%
%  Paul S�derlind, Paul.Soderlind@unisg.ch, Aug 2000, July 2007
%----------------------------------------------------------------------------

Q = (Q + Q')/2;                %to make symmetric
R = (R + R')/2;

n = n1 + n2;
k = size(R,1);                %No. of control variables

G =  [ eye(n),       zeros(n,k),   zeros(n,n)   ;
       zeros(n,n),   zeros(n,k),   (bet*A')     ;
       zeros(k,n),   zeros(k,k),   (-B')        ];

D =  [ A,            B,            zeros(n,n)   ;
       (-bet*Q),     (-bet*U),     eye(n)       ;
       U',           R,            zeros(k,n)   ];


G11 = G(:,1:n1);
G12 = G(:,n1+1:n1+n2);
G13 = G(:,n1+n2+1:n1+n2+k+n1);
G14 = G(:,n1+n2+k+n1+1:n1+n2+k+n1+n2);
D11 = D(:,1:n1);
D12 = D(:,n1+1:n1+n2);
D13 = D(:,n1+n2+1:n1+n2+k+n1);
D14 = D(:,n1+n2+k+n1+1:n1+n2+k+n1+n2);


G = [ G11, G14, G12, G13 ];          %x1,x2,(u,p1),p2 -> x1,p2,x2,(u,p1)
D = [ D11, D14, D12, D13 ];


if exist('OCTAVE_VERSION');              %Octave, real generalized Schur, sort with abs(lambda)>=1 last
  [S,T,Z,lambda] = qz(G,D,'B');          %G=QSZ' and D=QTZ', lambda = generalized eigenvalues
  if length(lambda) < size(S,2);         %if missing eigenvalues, add them as 999 ('infinite')
    lambda = [lambda;999*ones(size(S,2)-length(lambda),1)];
  end;
  logcon = 1 <= (abs(lambda)*cutoff);    %1 for stable eigenvalue
else;                                    %MatLab
  [S,T,Qa,Z] = qz(G,D);    %MatLab: G=Q'SZ' and D=Q'TZ'; Paul S:  G=QSZ' and D=QTZ', but Q isn't used
  %[S,T,Qa,Z] = reorder(S,T,Qa,Z);   % reordering of generalized eigenvalues, T(i,i)/S(i,i), in ascending order
  logconA = abs(diag(T)) <= (abs(diag(S))*cutoff);   %selecting stable eigenvalues
  [S,T,Qa,Z] = ordqz(S,T,Qa,Z,logconA);
  logcon = abs(diag(T)) <= (abs(diag(S))*cutoff);   %1 for stable eigenvalue
end;


if sum(logcon) < n;
  warning('Too few stable roots: no stable solution');
  M = NaN; C = NaN;
  return;
elseif sum(logcon) > n;
  warning('Too many stable roots: inifite number of stable solutions');
  M = NaN; C = NaN;
  return;
end;

Stt = S(1:n,1:n);
Ttt = T(1:n,1:n);
Zkt = Z(1:n,1:n);
Zlt = Z(n+1:n+k+n,1:n);

if cond(Zkt) > 1e+14;
  warning('Zkt is singular: rank condition for solution not satisfied');
  M = NaN; C = NaN;
  return;
end;

Zkt_1 = eye(size(Zkt))/Zkt;         %inverting
Stt_1 = eye(size(Stt))/Stt;


M = real(Zkt*Stt_1*Ttt*Zkt_1);      %[x1(t+1),p2(t+1)] = M*[x1(t),p2(t)]+e(t+1)
C = real(Zlt*Zkt_1);                %[x2(t),u(t),p1(t)] =C*[x1(t),p2(t)]
%-----------------------------------------------------------------------

