function z = itm_percentiles(reliability, confidence, location)
%ITM_PERCENTILES Validate ITM percentages and convert them to normal deviates.
%   z = ITM_PERCENTILES(reliability, confidence, location) checks that
%   every percentage is in (0, 100) and returns a struct with fields
%     T     deviates for time (reliability), size of reliability
%     S     deviates for situation (confidence), size of confidence
%     L     deviate for location (scalar)
%     size  output size, reliability and confidence under implicit expansion
%
%   itm_pathloss_rev1 calls this once and passes z to itm_p2p_core for
%   every link, so a reliability array is validated and converted once per
%   call instead of once per link. Scalars stay scalars: implicit expansion
%   in the variability step gives the same values as expanding first.
%
%   Deviates use the Abramowitz and Stegun 26.2.23 approximation of the
%   inverse complementary normal CDF, exactly as InverseComplementary-
%   CumulativeDistributionFunction.cpp in NTIA ITM v1.4. (norminv/erfcinv
%   are exact and would not match the C++.)

% min and max are single reductions with no temporaries; the elementwise
% form built two full logical arrays (about 20 ms for 1e6 values).
if min(confidence, [], 'all') <= 0 || max(confidence, [], 'all') >= 100
    error('itm:InvalidConfidence', 'ITM error 1006: Confidence percentage must be in (0, 100).');
end
if min(reliability, [], 'all') <= 0 || max(reliability, [], 'all') >= 100
    error('itm:InvalidReliability', 'ITM error 1007: Reliability percentage must be in (0, 100).');
end
if location <= 0 || location >= 100
    error('itm:InvalidLocation', 'ITM error 1004: Location percentage must be in (0, 100).');
end
out_size = broadcast_size(size(reliability), size(confidence));
z = struct('T', inverse_ccdf(reliability / 100), 'S', inverse_ccdf(confidence / 100), ...
    'L', inverse_ccdf(location / 100), 'size', out_size);
end

function sz = broadcast_size(a, b)
% Output size of a .* b under implicit expansion, without allocating it
n = max(numel(a), numel(b));
a(end + 1:n) = 1;
b(end + 1:n) = 1;
if any(a ~= b & a ~= 1 & b ~= 1)
    error('itm:SizeMismatch', ...
        'reliability and confidence must have compatible sizes for implicit expansion.');
end
sz = max(a, b);
sz(a == 0 | b == 0) = 0;
end

function Q = inverse_ccdf(q)
% Branch-free form of the C++: x = min(q, 1 - q), and the sign flip for
% q > 0.5 is a multiplication by -1, so the values are bit-identical to
% the logical-indexing form without the extra index arrays.
C_0 = 2.515516; C_1 = 0.802853; C_2 = 0.010328;
D_1 = 1.432788; D_2 = 0.189269; D_3 = 0.001308;
x = min(q, 1.0 - q);
T_x = sqrt(-2.0 * log(x));
zeta_x = ((C_2 * T_x + C_1) .* T_x + C_0) ./ (((D_3 * T_x + D_2) .* T_x + D_1) .* T_x + 1.0);
Q = (T_x - zeta_x) .* (1 - 2 * (q > 0.5));
end
