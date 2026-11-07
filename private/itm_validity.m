function itm_validity(wbits, d_km, mode)
%ITM_VALIDITY Raise errors or warnings for ITM inputs outside the model's range.
%   itm_validity(wbits, d_km, mode) checks one or more links. wbits holds
%   the NTIA warning flags of each link (uint32, from itm_p2p_core) and
%   d_km each path length.
%
%   mode:
%     "error"  (default in the public functions) A path shorter than 1 km
%              or longer than 2000 km, the range NTIA states for ITM,
%              raises itm:validity:Distance. The NTIA flags for inputs
%              near their limits (terminal height, frequency, distance,
%              a percentage far in a tail, low surface refractivity) raise
%              one MATLAB warning, itm:validity:Caution, that names the
%              conditions and the links they apply to. The horizon
%              geometry flags (0x0080 to 0x1000) are common on real
%              terrain, so they stay in info.warnings without a MATLAB
%              warning.
%     "warn"   As "error", but the distance check is a warning too.
%     "off"    No checks; the NTIA flags are only in info.warnings. Use
%              this to reproduce NTIA reference results.
%
%   Frequency, terminal heights, refractivity, and the other inputs NTIA
%   treats as hard limits always raise errors (itm:Invalid*), whatever the
%   mode.

if mode == "off" || ~any(wbits)
    return
end
wbits = uint32(wbits(:));
d_km = d_km(:);
n = numel(wbits);

dist_bits = uint32(16 + 64);                % > 2000 km, < 1 km (Warnings.h)
bad = bitand(wbits, dist_bits) ~= 0;
if any(bad)
    msg = sprintf("ITM is valid for paths of 1 to 2000 km. %s Set validity=""warn"" to compute anyway.", ...
        local_links(find(bad), d_km(bad), n)); %#ok<FNDSB> indices go in the message
    if mode == "error"
        error("itm:validity:Distance", "%s", msg);
    end
    warning("itm:validity:Distance", "%s", msg);
    wbits = bitand(wbits, bitcmp(dist_bits));
end

% Horizon-geometry flags (0x0080-0x1000) describe the terrain, not the
% inputs; they set on most paths with a nearby obstacle
wbits = bitand(wbits, bitcmp(uint32(hex2dec('1F80'))));
if ~any(wbits)
    return
end
% One warning for the whole call: each condition with the links it hit
bits = uint32(2 .^ (0:14));
lines = strings(0, 1);
for b = bits(any(bitand(wbits, bits) ~= 0, 1)) % at most 13 conditions
    hit = find(bitand(wbits, b) ~= 0);
    lines(end + 1) = "  " + string(itm_warning_text(b)) + local_which(hit, n); %#ok<AGROW> 13 at most
end
warning("itm:validity:Caution", "ITM result needs care:\n%s\nSee info.warnings, or set validity=""off"" to silence.", ...
    strjoin(lines, newline));
end

function txt = local_links(idx, d_km, n)
% "Path length is 0.52 km." or "Links 3, 7 (0.52, 2400 km) are outside it."
if n == 1
    txt = sprintf("Path length is %.3g km.", d_km);
    return
end
show = min(numel(idx), 10);
txt = sprintf("%d of %d links are outside it: link %s (%s km)", numel(idx), n, ...
    strjoin(string(idx(1:show)), ", "), strjoin(compose("%.3g", d_km(1:show)), ", "));
if numel(idx) > show
    txt = txt + ", ...";
end
txt = txt + ".";
end

function txt = local_which(idx, n)
if n == 1
    txt = "";
elseif numel(idx) <= 10
    txt = " (link " + strjoin(string(idx), ", ") + ")";
else
    txt = sprintf(" (%d of %d links)", numel(idx), n);
end
end
