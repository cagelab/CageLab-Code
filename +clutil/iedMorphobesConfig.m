function config = iedMorphobesConfig(in, metaTable)
% IEDMORPHOBESCONFIG Return the per-set stimulus specification for the
% morphobes IED task.
%   config = iedMorphobesConfig(in, metaTable)
%
% Reads the task settings from the in struct and derives every stimulus
% level directly from the morphobes metadata table, so every returned
% value is guaranteed to exist in the dataset. (The earlier hardcoded
% level matrices referenced shape/colour/appendage levels that the
% current procedural dataset does not contain — level encodings are
% non-contiguous, e.g. shape 0,1,2,4,7,8,11 — so lookups silently
% returned empty.)
%
% Settings used (normally filled by clutil.checkInput):
%   numTargets          2 or 4 targets.
%   idDimension         intra-dimensional (relevant) dimension:
%                       'shape', 'colour', 'appendage' or 'texture'.
%   edDimension         extra-dimensional dimension, relevant in set 3
%                       (EDS/EDR).
%   distractors         true  -> the non-relevant dimensions take their
%                                configured values (fixed or randomised);
%                       false -> the non-relevant dimensions are held
%                                neutral (level 0).
%   randomiseDistractors true  -> draw distractor values from the
%                                 metaTable levels each trial;
%                       false -> use distractorOne / distractorTwo.
%                       Ignored (with a warning) when distractors=false.
%   distractorOne       fixed value for the first non-ID/ED dimension
%                       (used when distractors=true, randomiseDistractors=false).
%   distractorTwo       fixed value for the second non-ID/ED dimension.
%   useExemplars        true  -> draw a fresh exemplar from the metaTable
%                                each trial;
%                       false -> fixed exemplar (0, or the lowest level
%                                available in the dataset).
%
% Returns:
%   config.numTargets
%   config.idDimension / config.edDimension     canonical singular names
%   config.distractors / config.randomiseDistractors / config.useExemplars
%   config.distractorOne / config.distractorTwo (clamped to valid levels)
%   config.distractorDims                       {1x2} the two non-ID/ED dims
%   config.available                            struct: levels present in
%                                               metaTable per dimension
%   config.sets                                 struct array 1x3, one entry
%                                               per IED stimulus set
%                                               (1: SD/SR/CD/CR, 2: IDS/IDR,
%                                               3: EDS/EDR):
%       sets(n).setNum
%       sets(n).relDim                   relevant dimension for this set
%       sets(n).relLevels                1xnumTargets levels for relDim
%       sets(n).nonRelevantDims          cellstr of non-relevant dims
%       sets(n).distractorValues         cell 1xK of 1xN fixed values
%                                        (zeros when distractors=false)
%       sets(n).distractorPools          cell 1xK of 1xM pools used when
%                                        distractors && randomiseDistractors
%       sets(n).exemplar                 fixed exemplar (useExemplars=false)
%       sets(n).exemplarPool             available exemplars
%                                        (useExemplars=true)
%
% The task presents, per trial in set n: the numTargets samples
% (relDim = relLevels, non-relevant dims = distractorValues or a fresh
% draw from distractorPools, exemplar = exemplar or exemplarPool draw).
% This gives an explicit, testable description of exactly which morphobe
% samples appear on each trial.

%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md

	arguments (Input)
		in struct
		metaTable table
	end
	arguments (Output)
		config struct
	end

	allDims = {'shape', 'colour', 'appendage', 'texture'};
	colMap = containers.Map(allDims, ...
		{'shape_level', 'colour_level', 'appendage_level', 'texture_level'});

	% ---------------------------------------------------------------
	% validate numTargets before applying defaults that depend on it
	% ---------------------------------------------------------------
	if ~isfield(in, 'numTargets') || isempty(in.numTargets)
		in.numTargets = 2;
	end
	numTargets = in.numTargets;
	if ~ismember(numTargets, [2 4])
		error('iedMorphobesConfig:InvalidNumTargets', ...
			'numTargets must be 2 or 4 (got %g).', numTargets);
	end

	% ---------------------------------------------------------------
	% settings defaults (callers normally use clutil.checkInput first;
	% this keeps the config directly callable in tests)
	% ---------------------------------------------------------------
	d = struct( ...
		'idDimension', 'colour', ...
		'edDimension', 'shape', ...
		'distractors', numTargets == 4, ...
		'randomiseDistractors', true, ...
		'distractorOne', 1, ...
		'distractorTwo', 1, ...
		'useExemplars', numTargets == 4);
	f = fieldnames(d);
	for i = 1:numel(f)
		if ~isfield(in, f{i}) || isempty(in.(f{i}))
			in.(f{i}) = d.(f{i});
		end
	end

	% ---------------------------------------------------------------
	% normalise and validate dimensions
	% ---------------------------------------------------------------
	idDim = clutil.normaliseDimension(in.idDimension);
	edDim = clutil.normaliseDimension(in.edDimension);
	if isempty(idDim) || isempty(edDim)
		error('iedMorphobesConfig:InvalidDimension', ...
			'idDimension and edDimension must be one of: shape, colour, appendage, texture.');
	end
	if strcmp(idDim, edDim)
		error('iedMorphobesConfig:SameDimensions', ...
			'idDimension and edDimension must be different dimensions.');
	end
	distractorDims = allDims(~ismember(allDims, {idDim, edDim}));

	% ---------------------------------------------------------------
	% available levels per dimension, straight from the metaTable
	% ---------------------------------------------------------------
	available = struct();
	for i = 1:numel(allDims)
		dim = allDims{i};
		col = colMap(dim);
		if ~ismember(col, metaTable.Properties.VariableNames)
			error('iedMorphobesConfig:MissingColumn', ...
				'metadata table has no column ''%s'' required for dimension ''%s''.', col, dim);
		end
		lv = unique(metaTable.(col));
		if ~isnumeric(lv)
			error('iedMorphobesConfig:NonNumericLevels', ...
				'metadata column ''%s'' must be numeric.', col);
		end
		available.(dim) = sort(lv(:))';
	end
	if ~ismember('exemplar', metaTable.Properties.VariableNames)
		error('iedMorphobesConfig:MissingColumn', ...
			'metadata table has no ''exemplar'' column.');
	end
	exemplarLevels = sort(double(unique(metaTable.exemplar)))';
	if numel(exemplarLevels) < 1
		error('iedMorphobesConfig:NoExemplars', ...
			'metadata table contains no exemplar levels.');
	end

	% ---------------------------------------------------------------
	% fixed distractor values must exist in the dataset
	% ---------------------------------------------------------------
	d1 = clampLevel(distractorDims{1}, in.distractorOne, available);
	d2 = clampLevel(distractorDims{2}, in.distractorTwo, available);

	config.numTargets = numTargets;
	config.idDimension = idDim;
	config.edDimension = edDim;
	config.distractors = logical(in.distractors);
	config.randomiseDistractors = logical(in.randomiseDistractors);
	config.useExemplars = logical(in.useExemplars);
	config.distractorOne = d1;
	config.distractorTwo = d2;
	config.distractorDims = distractorDims;
	config.available = available;

	if ~config.distractors && config.randomiseDistractors
		warning('iedMorphobesConfig:RandomiseIgnored', ...
			'randomiseDistractors is ignored while distractors is false; non-relevant dimensions are held neutral.');
	end

	% ---------------------------------------------------------------
	% per-set specification
	% ---------------------------------------------------------------
	for s = 1:3
		if s <= 2
			relDim = idDim;      % ID dimension relevant for sets 1-2
		else
			relDim = edDim;      % ED dimension relevant for set 3 (EDS/EDR)
		end
		nonRelevant = allDims(~strcmp(allDims, relDim));
		nR = numel(nonRelevant);
		vals = cell(1, nR);
		pools = cell(1, nR);
		for k = 1:nR
			dim = nonRelevant{k};
			if config.distractors && config.randomiseDistractors
				% per-trial draw from every level present in the dataset
				pools{k} = available.(dim);
				vals{k} = zeros(1, numTargets); %#ok<NASGU> unused in this mode
			elseif config.distractors
				% fixed values: distractorOne/Two for the two persistent
				% distractors; neutral 0 for the temporarily irrelevant
				% ID/ED dimension
				fixedVal = 0;
				if strcmp(dim, distractorDims{1})
					fixedVal = d1;
				elseif strcmp(dim, distractorDims{2})
					fixedVal = d2;
				end
				vals{k} = repmat(fixedVal, 1, numTargets);
				pools{k} = [];
			else
				% distractors off: hold every non-relevant dimension neutral
				vals{k} = zeros(1, numTargets);
				pools{k} = [];
			end
		end
		sets(s).setNum = s; %#ok<AGROW>
		sets(s).relDim = relDim; %#ok<AGROW>
		sets(s).relLevels = pickLevels(available.(relDim), s, numTargets); %#ok<AGROW>
		sets(s).nonRelevantDims = nonRelevant; %#ok<AGROW>
		sets(s).distractorValues = vals; %#ok<AGROW>
		sets(s).distractorPools = pools; %#ok<AGROW>
		if config.useExemplars
			sets(s).exemplar = []; %#ok<AGROW>
			sets(s).exemplarPool = exemplarLevels; %#ok<AGROW>
		else
			sets(s).exemplar = exemplarFixed(exemplarLevels); %#ok<AGROW>
			sets(s).exemplarPool = []; %#ok<AGROW>
		end
	end
	config.sets = sets;
end

% ===================================================================
%> @brief Pick numTargets levels spread across the available levels,
%> offset per set so consecutive sets share as few values as possible.
%> Deterministic (no random state), so tests can verify the result.
% ===================================================================
function levels = pickLevels(available, setN, numTargets)
	M = numel(available);
	if numTargets > M
		error('iedMorphobesConfig:NotEnoughLevels', ...
			'Dimension has %d available levels but %d targets requested.', M, numTargets);
	end
	if numTargets == 1
		idx = 1;
	elseif numTargets == 2
		% Two targets: pair levels roughly half a catalogue apart so the
		% two samples are as visually distinct as possible (e.g. colour
		% coral/green, amber/violet, lime/magenta). Each set shifts the
		% pair through the available levels.
		half = max(1, floor(M / 2));
		a = mod(setN - 1, half);
		idx = [a + 1, a + 1 + half];
		idx(idx > M) = M;
	else
		base = round(linspace(1, M, numTargets));
		shift = max(1, floor(M / numTargets));
		idx = mod(base + (setN - 1) * shift - 1, M) + 1;
		if numel(unique(idx)) < numTargets
			idx = 1:numTargets; % pathological fallback (tiny level set)
		end
	end
	levels = available(idx);
end

% ===================================================================
%> @brief Clamp a fixed distractor value to a level that exists in the
%> dataset, warning when the requested value is not available.
% ===================================================================
function v = clampLevel(dim, value, available)
	if isempty(value) || ~isfinite(value)
		value = 0;
	end
	lv = available.(dim);
	if ismember(value, lv)
		v = value;
		return;
	end
	[~, i] = min(abs(lv - value));
	v = lv(i);
	warning('iedMorphobesConfig:InvalidDistractorValue', ...
		'Fixed distractor value %g for dimension ''%s'' is not in the dataset; using nearest available level %g.', ...
		value, dim, v);
end

% ===================================================================
%> @brief Fixed exemplar: 0 when present, otherwise the lowest level
%> available in the dataset.
% ===================================================================
function ex = exemplarFixed(exemplarLevels)
	ex = exemplarLevels(1);
	if ~ismember(0, exemplarLevels)
		warning('iedMorphobesConfig:NoExemplarZero', ...
			'Exemplar 0 is not present in the dataset; using lowest available exemplar %g.', ex);
	end
end
