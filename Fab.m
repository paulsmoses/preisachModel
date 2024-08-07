function [ FABout ] = Fab( alpha , beta , x )
%
%   Programmer: Paul S. Moses
%   Date: 19 FEB 2010
%
% This function is the F(alpha,beta) preisach relationship which is equal
% to one-half of the output increments along the first-order-transition curve.
%
% Note, the formula consists of a summation of tanh-sech terms.  The
% summation terms are carried out by vectorizing the different coefficients
% of the summation terms.  Finally, the vectorized sum terms are summed.

A = x.A;
u0 = x.u0;
Ms = x.Mi*A/u0;
e = x.e;
P = x.Pi;

FABout = sum( (repmat(Ms,1,length(alpha))/2).*(tanh(P*alpha)-tanh(P*beta) ...
          -repmat(e/2,1,length(alpha)).*((sech(P*beta)).^2.*tanh(P*alpha) ...
          -(sech(P*alpha)).^2.*tanh(P*beta))) , 1 );
