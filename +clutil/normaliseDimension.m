function dim = normaliseDimension(dim)
	% NORMALISEDIMENSION Normalise a morphobes dimension name to its
	% canonical singular form.
	%   dim = normaliseDimension(dim)
	%
	% Accepts case-insensitive, plural and whitespace-tolerant variants:
	%   'shape' / 'shapes'         -> 'shape'
	%   'colour' / 'colours'       -> 'colour'
	%   'appendage' / 'appendages' -> 'appendage'
	%   'texture' / 'textures'     -> 'texture'
	% Anything else returns '' so the caller can warn and apply a default.
	%
	% @param dim char|string dimension name to normalise
	% @return dim char canonical dimension name or ''
	arguments (Input)
		dim {mustBeTextScalar}
	end
	arguments (Output)
		dim char
	end
	dim = strip(lower(char(dim)));
	% strip a trailing 's' to accept plurals, e.g. appendages -> appendage
	if endsWith(dim, 's') && numel(dim) > 1
		cand = dim(1:end-1);
		if ismember(cand, {'shape', 'colour', 'appendage', 'texture'})
			dim = cand;
		end
	end
	if ~ismember(dim, {'shape', 'colour', 'appendage', 'texture'})
		dim = '';
	end
end
