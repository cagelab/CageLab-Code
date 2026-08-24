function config = iedMorphobesConfig(in, metaTable)
% IEDMORPHOBESCONFIG Return the per-set stimulus specification for the
% morphobes IED task.
%   config = iedMorphobesConfig(in, metaTable)
%
% Reads the task settings from the in struct and derives every stimulus
% level directly from the morphobes metadata table, so every returned
% value is guaranteed to exist in the dataset.
%
% Stimulus logic (identical for numTargets = 2 and 4):
%   The two task-relevant dimensions (idDimension and edDimension) each
%   provide TWO disjoint sample sets of numTargets levels, drawn at random
%   from the levels present in the dataset:
%     Set A — used by the first four stages (sd sr cd cr)
%     Set B — used by the shift stages (ids idr eds edr)
%   This requires at least 2*numTargets levels in each task-relevant
%   dimension. The current dataset has 8 colours and 8 shapes but only 5
%   appendages and 5 textures, so with numTargets = 4 only colour and
%   shape may be used as ID/ED dimensions (an error is thrown otherwise);
%   with numTargets = 2 any of the four dimensions is permitted.
%
% Per stage the correct (rewarded) level of the relevant dimension is
% precomputed into config.correct (constant across the trials of that
% stage, per the CANTAB logic):
%     sd  — fresh random level from Set A
%     sr  — fresh random level from Set A, different from sd
%     cd  — keeps the correct level of sr
%     cr  — fresh random level from Set A, different from cd
%     ids — fresh random level from Set B (ID dimension)
%     idr — fresh random level from Set B, different from ids
%     eds — fresh random level from Set B (ED dimension)
%     edr — fresh random level from Set B, different from eds
% On each trial the task presents all numTargets levels of the relevant
% dimension (one of which is the correct level) plus all numTargets levels
% of the other task-relevant (extra) dimension, except in sd/sr where the
% extra dimension is held at the fixed value sets(n).extraFixed. The two
% remaining dimensions are persistent distractors, configured via
% distractors / randomiseDistractors / distractorOne / distractorTwo.
%
% Settings used (normally filled by clutil.checkInput):
%   numTargets          2 or 4 targets.
%   idDimension         intra-dimensional (relevant) dimension:
%                       'shape', 'colour', 'appendage' or 'texture'.
%   edDimension         extra-dimensional dimension, relevant in set 3
%                       (EDS/EDR).
%   stages              (optional) string array of stage codes; the
%                       correct-value table is computed for exactly these
%                       stages (defaults to the full 8-stage sequence).
%   distractors         true  -> the two persistent distractor dimensions
%                                take their configured values (fixed or
%                                randomised);
%                       false -> the persistent distractor dimensions are
%                                held neutral (level 0).
%   randomiseDistractors true  -> draw one random distractor level per
%                                 trial (same level on all targets);
%                       false -> use distractorOne / distractorTwo.
%                       Ignored (with a warning) when distractors=false.
%   distractorOne       fixed value for the first persistent distractor
%                       dimension (in canonical order
%                       shape, colour, appendage, texture).
%   distractorTwo       fixed value for the second persistent distractor.
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
%   config.distractorDims                       {1x2} the two persistent
%                                               distractor dims
%   config.available                            struct: levels present in
%                                               metaTable per dimension
%   config.correct                              struct keyed by stage name
%                                               (sd sr cd cr ids idr eds
%                                               edr) -> correct level for
%                                               that stage's relevant dim
%   config.sets                                 struct array 1x3, one entry
%                                               per IED stimulus set
%                                               (1: SD/SR/CD/CR -> Set A,
%                                               2: IDS/IDR -> Set B,
%                                               3: EDS/EDR -> Set B):
%       sets(n).setNum
%       sets(n).relDim                   relevant dimension for this set
%       sets(n).relLevels                1xnumTargets levels for relDim
%       sets(n).extraDim                 the other task-relevant dimension
%       sets(n).extraLevels              1xnumTargets levels for extraDim
%       sets(n).extraFixed               fixed level of extraDim used in
%                                        sd/sr (random member of
%                                        extraLevels for set 1; unused for
%                                        sets 2-3 which always vary)
%       sets(n).distractorDims           {1x2} the persistent distractors
%       sets(n).distractorValues         cell 1x2 of 1xN fixed values
%                                        (zeros when distractors=false)
%       sets(n).distractorPools          cell 1x2 of 1xM pools used when
%                                        distractors && randomiseDistractors
%       sets(n).exemplar                 fixed exemplar (useExemplars=false)
%       sets(n).exemplarPool             available exemplars
%                                        (useExemplars=true)
%
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

	% ---------------------------------------------------------------
	% every task-relevant dimension needs two disjoint sets of
	% numTargets levels (Set A: sd/sr/cd/cr, Set B: ids/idr/eds/edr).
	% The current dataset has 8 colours and 8 shapes but only 5
	% appendages and 5 textures, so numTargets=4 is restricted to
	% colour/shape for ID/ED while numTargets=2 allows any dimension.
	% ---------------------------------------------------------------
	taskDims = {idDim, edDim};
	for i = 1:numel(taskDims)
		dim = taskDims{i};
		if numel(available.(dim)) < 2 * numTargets
			error('iedMorphobesConfig:NotEnoughLevels', ...
				'Dimension ''%s'' has %d available levels but numTargets=%d requires at least %d so two disjoint sample sets can be drawn. Use colour or shape for 4-target IED.', ...
				dim, numel(available.(dim)), numTargets, 2 * numTargets);
		end
	end

	% split each task-relevant dimension into Set A (first stages) and
	% Set B (shift stages) — random, disjoint, all from the dataset
	setSpec = struct();
	[a, b] = splitLevels(available.(idDim), numTargets);
	setSpec.(idDim).setA = a;
	setSpec.(idDim).setB = b;
	[a, b] = splitLevels(available.(edDim), numTargets);
	setSpec.(edDim).setA = a;
	setSpec.(edDim).setB = b;

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
			'randomiseDistractors is ignored while distractors is false; persistent distractor dimensions are held neutral.');
	end

	% ---------------------------------------------------------------
	% correct (rewarded) level per stage — computed once for the stage
	% sequence actually requested, constant across trials of a stage
	% ---------------------------------------------------------------
	if isfield(in, 'stages') && ~isempty(in.stages)
		stagesList = strip(string(in.stages(:)'));
		stagesList = stagesList(~ismissing(stagesList) & stagesList ~= "");
	else
		stagesList = ["sd" "sr" "cd" "cr" "ids" "idr" "eds" "edr"];
	end
	config.correct = computeCorrectLevels(stagesList, idDim, edDim, setSpec);

	% ---------------------------------------------------------------
	% per-set specification
	% ---------------------------------------------------------------
	for s = 1:3
		if s <= 2
			relDim = idDim;      % ID dimension relevant for sets 1-2
			extraDim = edDim;    % the other task-relevant dimension
		else
			relDim = edDim;      % ED dimension relevant for set 3 (EDS/EDR)
			extraDim = idDim;
		end
		if s == 1
			setN = 'A';          % sd/sr/cd/cr use Set A
		else
			setN = 'B';          % ids/idr/eds/edr use Set B
		end
		relLevels = setSpec.(relDim).(['set' setN]);
		extraLevels = setSpec.(extraDim).(['set' setN]);

		% persistent distractors: the two non-ID/ED dimensions
		nR = numel(distractorDims);
		vals = cell(1, nR);
		pools = cell(1, nR);
		for k = 1:nR
			dim = distractorDims{k};
			if config.distractors && config.randomiseDistractors
				% one random level per trial, same on all targets
				pools{k} = available.(dim);
				vals{k} = zeros(1, numTargets); %#ok<NASGU> unused in this mode
			elseif config.distractors
				% fixed values: distractorOne/Two for the two persistent
				% distractors
				fixedVal = 0;
				if strcmp(dim, distractorDims{1})
					fixedVal = d1;
				elseif strcmp(dim, distractorDims{2})
					fixedVal = d2;
				end
				vals{k} = repmat(fixedVal, 1, numTargets);
				pools{k} = [];
			else
				% distractors off: hold every persistent distractor neutral
				vals{k} = zeros(1, numTargets);
				pools{k} = [];
			end
		end

		sets(s).setNum = s; %#ok<AGROW>
		sets(s).relDim = relDim; %#ok<AGROW>
		sets(s).relLevels = relLevels; %#ok<AGROW>
		sets(s).extraDim = extraDim; %#ok<AGROW>
		sets(s).extraLevels = extraLevels; %#ok<AGROW>
		if s == 1
			% sd/sr show the extra dimension at one fixed level for all
			% targets; a random member of Set A keeps it tied to the
			% exemplars the subject will see in later stages.
			sets(s).extraFixed = extraLevels(randi(numel(extraLevels))); %#ok<AGROW>
		else
			% sets 2-3 have no sd/sr stage; extraFixed is unused
			sets(s).extraFixed = extraLevels(1); %#ok<AGROW>
		end
		sets(s).distractorDims = distractorDims; %#ok<AGROW>
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
%> @brief Split the available levels of one dimension into two disjoint
%> sets of numTargets levels: Set A for the first stages, Set B for the
%> shift stages (drawn at random from the remaining levels). Random —
%> call with a seeded rng for deterministic tests.
% ===================================================================
function [setA, setB] = splitLevels(levels, numTargets)
	perm = levels(randperm(numel(levels)));
	setA = perm(1:numTargets);
	rest = perm(numTargets+1:end);
	nB = min(numTargets, numel(rest));
	setB = rest(randperm(numel(rest), nB));
end

% ===================================================================
%> @brief Precompute the correct (rewarded) level for every stage in the
%> requested sequence. Constant per stage; follows the CANTAB logic:
%> fresh draw for sd/ids/eds, fresh draw excluding the previous level
%> for sr/cr/idr/edr, keep the previous level for cd.
% ===================================================================
function correct = computeCorrectLevels(stagesList, idDim, edDim, setSpec)
	correct = struct();
	prevLevel = []; % no previous stage yet (levels are >= 0, so [] is safe)
	for i = 1:numel(stagesList)
		st = char(stagesList(i));
		switch st
			case {'sd', 'sr', 'cd', 'cr'}
				relDim = idDim;
				setN = 'A';
			case {'ids', 'idr'}
				relDim = idDim;
				setN = 'B';
			case {'eds', 'edr'}
				relDim = edDim;
				setN = 'B';
			otherwise
				% unknown stage: treat like sd (task validates first)
				relDim = idDim;
				setN = 'A';
		end
		levels = setSpec.(relDim).(['set' setN]);
		switch st
			case {'sr', 'cr', 'idr', 'edr'}
				level = drawNewLevel(levels, prevLevel);
			case 'cd'
				if ~isempty(prevLevel) && ismember(prevLevel, levels)
					level = prevLevel; % keep the correct level of sr
				else
					level = levels(randi(numel(levels)));
				end
			otherwise % sd, ids, eds
				level = levels(randi(numel(levels)));
		end
		correct.(st) = level;
		prevLevel = level;
	end
end

% ===================================================================
%> @brief Draw a level at random, excluding a previous level when that
%> previous level belongs to the same sample set.
% ===================================================================
function level = drawNewLevel(levels, exclude)
	pool = levels;
	if ~isempty(exclude) && ismember(exclude, levels)
		pool = setdiff(levels, exclude);
	end
	level = pool(randi(numel(pool)));
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
