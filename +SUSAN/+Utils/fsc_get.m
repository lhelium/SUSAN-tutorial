function fsc_arr = fsc_get(arg1,arg2,arg3)
% FSC_GET calculates the FSC between two volumes.
%   FSC = FSC_GET(V1,V2) calculates the FSC between V1 and V2. The
%   inputs, V1 and V2, can be volumes or filenames of MRC files.
%   A spherical mask will be used by default.
%   FSC = FSC_GET(...,MSK) it uses the mask specified in MSK. It can 
%   be a volume or a filename of a MRC file.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is part of the Substack Analysis (SUSAN) framework.
% Copyright (c) 2018-2021 Ricardo Miguel Sanchez Loayza.
% Max Planck Institute of Biophysics
% Department of Structural Biology - Kudryashev Group.
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
% 
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if( nargin == 3 )
    fsc_arr = fsc_internal_3_volumes(arg1,arg2,arg3);
end

if( nargin == 2 )
    fsc_arr = fsc_internal_2_volumes(arg1,arg2);
end

if( nargin == 1 )
    if( isa( arg1, 'SUSAN.Data.ReferenceInfo' ) )
        if( length(arg1) == 1 )
            fsc_arr = fsc_internal_3_volumes(arg1.h1,arg1.h2,arg1.mask);
        else
            error('Only 1 SUSAN.Data.ReferenceInfo element is supported.');
        end
    else
        error('Unsupported input.');
    end
    
end

% For dfsc compatibility:
fsc_arr = fsc_arr(2:end);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function v = conditional_load_mrc(arg)

if( ischar(arg) )
    v = SUSAN.IO.read_mrc(arg);
else
    v = arg;
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fsc = fsc_internal_3_volumes(arg1,arg2,arg3)

v1  = conditional_load_mrc(arg1);
v2  = conditional_load_mrc(arg2);
msk = conditional_load_mrc(arg3);

fsc = fsc_core(v1,v2,msk);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fsc = fsc_internal_2_volumes(arg1,arg2)

v1  = conditional_load_mrc(arg1);
v2  = conditional_load_mrc(arg2);
N   = size(v1,1);
msk = SUSAN.Utils.mask_sphere(N/2,N);

fsc = fsc_core(v1,v2,msk);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fsc = fsc_core(v1,v2,msk)

if( ~isequal(size(v1),size(v2)) )
    error('Size mismatch of the input volumes.');
end

if( ~isequal(size(v1),size(msk)) )
    error('Size mismatch of the input volumes.');
end

H1 = fftshift(fftn(v1.*msk));
H2 = fftshift(fftn(v2.*msk));

num  = single(real(H1 .* conj( H2 )));
denA = single(H1 .* conj( H1 ));
denB = single(H2 .* conj( H2 ));

fsc = fsc_get_core( num, denA, denB );

end


