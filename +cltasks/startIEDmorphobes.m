function startIEDmorphobes(in)
	% startIEDmorphobes(in)
	% Start an Intra-Dimensional / Extra-Dimensional Set Shifting Task
	% (CANTAB derivative) using morphobes parametric microorganism stimuli.
	%
	% This unified function supports both 2-target (2D) and 4-target (4D)
	% configurations via the in.numTargets parameter:
	%   numTargets = 2 — two targets (left/right); any of the four dimensions
	%                 (shape, colour, appendage, texture) may be ID or ED.
	%   numTargets = 4 — four targets placed radially, equidistant from the
	%                 touch-initiation point; ID/ED must be colour or shape
	%                 (appendage/texture carry only 5 dataset levels, not
	%                 enough for two disjoint 4-sample sets).
	% The stimulus logic is identical for both target counts: each
	% task-relevant dimension provides two disjoint random sample sets
	% (Set A for sd/sr/cd/cr, Set B for ids/idr/eds/edr) and the correct
	% level per stage follows the CANTAB sequence (see
	% clutil.iedMorphobesConfig).
	%
	% The dataset folder defaults to resources/morphobes (falling back to
	% the legacy names morphobes_ied4d / morphobes_ied if present).
	%
	% in comes from CageLab GUI or can be a struct with the following fields:
	% Example:
	%   in = struct();
	%   in.taskType = 'sd cd cr ids idr eds edr'; % stages run in sequence
	%   in.numTargets = 4;        % 2 or 4 targets (2D or 4D variant)
	%   in.idDimension = 'colour'; % 'shape','colour','appendage','texture' — ID dim
	%   in.edDimension = 'shape';  % 'shape','colour','appendage','texture' — ED dim
	%   in.criterion = 6;         % consecutive correct to advance
	%   in.maxIncorrect = 50;     % incorrect trials on stage before task terminates
	%   in.distractors = true;    % show the two non-ID/ED dimensions; false holds
	%                             %   them neutral (0). Default: false for 2 targets,
	%                             %   true for 4 targets.
	%   in.randomiseDistractors = true; % draw distractor values from the dataset
	%                             %   levels each trial; false uses the fixed values
	%                             %   below. Ignored when distractors=false.
	%   in.distractorOne = 0;     % fixed value for the first non-ID/ED dimension
	%   in.distractorTwo = 0;     % fixed value for the second non-ID/ED dimension
	%   in.useExemplars = true;   % draw a fresh exemplar from the dataset each
	%                             %   trial; false uses exemplar 0. Default: false
	%                             %   for 2 targets, true for 4 targets.
	%   in.objectSize = 8;        % size of objects in degrees
	%   in.objectSep = 12;        % separation of objects in degrees
	%   in.distractorCenterAngle = 270; % centre angle (deg) of the radial layout
	%                             %   (PTB: 0 = right, 90 = down, 270 = up)
	%   in.distractorSpreadAngle = 0; % half-width (deg) of the radial arc;
	%                             %   <= 0 = full circle evenly spaced, rotated
	%                             %   by the centre angle; > 0 = arc spanning
	%                             %   centre +/- spread with the cardinal
	%                             %   slot(s) pulled in by the object-size
	%                             %   hypotenuse modifier (startThings pattern)
	%   in.sampleY = 0;           % unused with radial positioning (kept for
	%                             %   compatibility; targets sit at in.objectSep
	%                             %   from the touch-initiation point)
	%   in.trialTime = 5.0;       % max trial time in seconds
	%   in.targetHoldTime = 0.2;  % target hold time in seconds
	%   in.morphobesFolder = '';  % morphobes dataset folder
	%                              %   defaults to resources/morphobes
	%                              %   (legacy: morphobes_ied / morphobes_ied4d)
	%
	% The per-set stimulus specification (which morphobe samples are shown on
	% each trial) is computed by clutil.iedMorphobesConfig(in, metaTable):
	% sets 1-2 use the ID dimension as the relevant dimension, set 3 (EDS/EDR)
	% switches to the ED dimension; each set shows all numTargets levels of
	% the relevant and extra dimensions (extra held fixed in sd/sr), with the
	% two remaining dimensions as fixed or randomised persistent distractors.
	% The correct level for the current stage is config.correct.(stage).
	% All level values are derived from the dataset metadata, so they always
	% resolve to real stimuli.
	%
	% Stage meanings (CANTAB IED sequence):
	%   sd  - Simple Discrimination: ID dimension varies; distractors neutral.
	%   sr  - Simple Reversal: same stimuli as SD; reward contingency reverses.
	%   cd  - Compound Discrimination: all dimensions shown; ID relevant.
	%   cr  - Compound Reversal: same compound setup as CD; contingency reverses.
	%   ids - Intra-Dimensional Shift: new exemplars; ID dimension stays relevant.
	%   idr - Intra-Dimensional Reversal: same exemplars as IDS; reverses.
	%   eds - Extra-Dimensional Shift: new exemplars; relevant dimension switches
	%         (ID -> ED).
	%   edr - Extra-Dimensional Reversal: same exemplars as EDS; reverses.
	%

	if ~exist('in','var'); in = struct('task','ied','taskType','sd cd sr cr ids idr eds edr'); end
	in = clutil.checkInput(in);

	% Parse taskType into a row string array of stage codes.
	% Accepts 'sd cd cr ...' or the GUI array-literal format
	% '[ "sd" "sr" "cd" "cr" "ids" "idr" "eds" "edr" ]' (brackets, quotes
	% and commas are stripped).
	stages = string(in.taskType);
	if isscalar(stages)
		stages = replace(stages, {'[', ']', '"', '''', ',', ';'}, ' ');
		stages = split(strip(stages));
	end
	stages = lower(strip(stages));
	stages = stages(~ismissing(stages) & stages ~= "");
	stages = stages(:)';
	in.stages = stages;
	if ~isempty(stages)
		in.taskType = char(stages(1));
	end

	% IED progression defaults
	if ~isfield(in, 'criterion') || isempty(in.criterion); in.criterion = 6; end
	if ~isfield(in, 'maxIncorrect') || isempty(in.maxIncorrect); in.maxIncorrect = 50; end
	in.totalTrials = 1e6;

	% Number of targets: 2 (2D) or 4 (4D)
	if ~isfield(in, 'numTargets') || isempty(in.numTargets)
		in.numTargets = 2;
	end
	numTargets = in.numTargets;

	% Dimension assignment — normalised with clutil.normaliseDimension so
	% plurals ('appendages') and case variants ('Appendage') are accepted.
	if ~isfield(in, 'idDimension') || isempty(in.idDimension)
		in.idDimension = 'colour';
	end
	if ~isfield(in, 'edDimension') || isempty(in.edDimension)
		in.edDimension = 'shape';
	end
	in.idDimension = clutil.normaliseDimension(in.idDimension);
	in.edDimension = clutil.normaliseDimension(in.edDimension);
	validDims = {'shape','colour','appendage','texture'};
	if ~ismember(in.idDimension, validDims)
		warning('idDimension ''%s'' invalid. Defaulting to colour.', in.idDimension);
		in.idDimension = 'colour';
	end
	if ~ismember(in.edDimension, validDims)
		warning('edDimension ''%s'' invalid. Defaulting to shape.', in.edDimension);
		in.edDimension = 'shape';
	end
	if strcmp(in.idDimension, in.edDimension)
		warning('idDimension and edDimension are the same. Using shape as edDimension.');
		in.edDimension = setdiff(validDims, in.idDimension);
		in.edDimension = in.edDimension{1};
	end

	% Morphobes dataset folder — default resolves to the current unified
	% dataset (resources/morphobes), falling back to legacy names
	% (morphobes_ied4d / morphobes_ied) for older resource checkouts.
	if ~isfield(in, 'morphobesFolder') || isempty(in.morphobesFolder)
		candidates = {fullfile(in.folder, 'morphobes'), ...
			fullfile(in.folder, 'morphobes_ied4d'), ...
			fullfile(in.folder, 'morphobes_ied')};
		idx = find(cellfun(@isfolder, candidates), 1);
		if isempty(idx); idx = 1; end
		in.morphobesFolder = candidates{idx};
	end

	bgName = 'abstract7.jpg';
	if numTargets == 4
		prefix = 'IEDmorphobes4D';
	else
		prefix = 'IEDmorphobes';
	end

	try
		%% ============================shared initialisation
		[sM, aM, rM, tM, r, dt, in] = clutil.initialise(in, bgName, prefix);

		%% ============================load morphobes metadata
		metaTable = readtable(fullfile(in.morphobesFolder, 'metadata.csv'), ...
			'VariableNamingRule', 'preserve', 'TextType', 'string');

		% 5-parameter lookup: (shape, colour, appendage, texture, exemplar)
		lookupPNG = @(shapeLv, colourLv, appendageLv, textureLv, exemplar) ...
			char(fullfile(in.morphobesFolder, metaTable.png_path(...
				metaTable.shape_level == shapeLv & ...
				metaTable.colour_level == colourLv & ...
				metaTable.appendage_level == appendageLv & ...
				metaTable.texture_level == textureLv & ...
				metaTable.exemplar == exemplar)));

		%% ============================validate all stages
		validTaskTypes = {'sd','sr','cd','cr','ids','idr','eds','edr'};
		for i = 1:length(stages)
			if ~ismember(stages(i), validTaskTypes)
				warning('Unknown task type %s. Defaulting to SD.', stages(i));
				stages(i) = 'sd';
			end
		end
		in.stages = stages;

		%% ============================dimension level configuration
		% Per-set stimulus specification derived from the task settings
		% and validated against the morphobes metadata table. Every level
		% value is taken from the dataset, so lookups always resolve.
		config = clutil.iedMorphobesConfig(in, metaTable);
		numTargets = config.numTargets;

		%% ============================create targets radially around fixation
		% Targets are placed at equal distance (in.objectSep) from the
		% touch-initiation point (r.fix), using polar->cartesian conversion
		% — the startThings positioning pattern. PTB convention: 0deg is
		% +x (RIGHT) and 90deg is +y (DOWN). distractorCenterAngle and
		% distractorSpreadAngle control the layout: spread <= 0 gives an
		% evenly spaced full circle rotated by the centre angle; spread > 0
		% gives an arc centred on the centre angle spanning +/- spread.
		% In the arc case the position(s) nearest the centre angle are
		% pulled in by the object-size hypotenuse modifier so large objects
		% do not inflate the inter-target spacing. The per-trial position
		% shuffle is applied in the trial loop via updateXY; here we only
		% give setup() valid start values.
		target1 = imageStimulus('size', in.objectSize, 'randomiseSelection', false);
		target2 = imageStimulus('size', in.objectSize, 'randomiseSelection', false);
		if numTargets == 2	
			targets = metaStimulus('stimuli', {target1 target2});
		else
			target3 = imageStimulus('size', in.objectSize, 'randomiseSelection', false);
			target4 = imageStimulus('size', in.objectSize, 'randomiseSelection', false);
			targets = metaStimulus('stimuli', {target1 target2 target3 target4});
		end
		if in.distractorSpreadAngle <= 0
			angs = linspace(0, 360, numTargets + 1);
			angs = angs(1:end-1) + in.distractorCenterAngle;
			radius = repmat(in.objectSep, 1, numTargets);
		else
			angs = linspace(in.distractorCenterAngle - in.distractorSpreadAngle, ...
				in.distractorCenterAngle + in.distractorSpreadAngle, numTargets);
			mod = in.objectSize * 0.414; % modifier for the length of hypotenuse greater than side
			radius = repmat(in.objectSep, 1, numTargets);
			d = abs(angs - in.distractorCenterAngle);
			radius(d == min(d)) = in.objectSep - mod;
		end
		% polarToCartesianPoints returns the full angle x radius grid; the
		% diagonal pairs each angle with its own radius
		[xAll, yAll] = sM.polarToCartesianPoints(r.fix.xPosition, r.fix.yPosition, angs(:), radius(:));
		xpos = diag(xAll)';
		ypos = diag(yAll)';
		for i = 1:numTargets
			targets{i}.xPosition = xpos(i);
			targets{i}.yPosition = ypos(i);
		end
		targets.stimulusSets{1} = 1:numTargets;
		targets.fixationChoice = 1;

		%% ============================setup
		setup(r.fix, sM);
		setup(targets, sM);
		hide(targets);

		in.doNegation = true;

		%% ============================IED stage progression state
		r.stageIdx = 1;
		r.consecutiveCorrect = 0;
		r.stageIncorrect = 0;
		r.stageTrialN = 0;
		r.stagesTotal = length(stages);
		r.stagesCompleted = 0;
		r.taskFailed = false;

		%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while r.keepRunning

			%% ==============================initialise trial
			r = clutil.initTrialVariables(r);
			txt = '';
			fail = false; hld = false; tch = false; % tch also set inside testHold

			%% ==============================determine stage parameters
			r.stage = stages(r.stageIdx);

			% Set number
			if ismember(r.stage, {'sd','sr','cd','cr'})
				setNum = 1;
			elseif ismember(r.stage, {'ids','idr'})
				setNum = 2;
			else
				setNum = 3;
			end

			% Per-set specification: relevant dimension and its sample
			% set, the other task-relevant (extra) dimension, persistent
			% distractor policy and exemplar handling — all derived from
			% the dataset metadata by clutil.iedMorphobesConfig.
			setCfg = config.sets(setNum);
			relDim = setCfg.relDim;
			extraDim = setCfg.extraDim;

			% Correct level for this stage: constant across its trials,
			% chosen by the config's stage state machine (sd/sr/cd/cr
			% share Set A, ids/idr/eds/edr share Set B; reversals pick a
			% new level, cd keeps sr's correct level).
			correctLevel = config.correct.(char(r.stage));

			%% ==============================select stimuli for targets
			% Stimulus values for targets (column = target)
			stimVals = struct('shape', zeros(1, numTargets), 'colour', zeros(1, numTargets), ...
				'appendage', zeros(1, numTargets), 'texture', zeros(1, numTargets));

			% Relevant dimension: all numTargets levels of the sample set
			% are shown every trial, assigned to targets in a fresh random
			% order; the target carrying the correct level is the one to
			% touch.
			relVals = setCfg.relLevels(randperm(numTargets));
			correctIdx = find(relVals == correctLevel, 1);
			stimVals.(relDim) = relVals;

			% Extra (other task-relevant) dimension: fixed for all targets
			% in sd/sr (simple discrimination — only the relevant
			% dimension varies), otherwise all numTargets levels of its
			% sample set in a fresh random order per trial (compound
			% discrimination).
			if ismember(r.stage, {'sd','sr'})
				stimVals.(extraDim) = repmat(setCfg.extraFixed, 1, numTargets);
			else
				stimVals.(extraDim) = setCfg.extraLevels(randperm(numTargets));
			end

			% Persistent distractor dimensions (the two non-ID/ED dims):
			% neutral (distractors=false), fixed distractorOne/Two values,
			% or one fresh random level per trial shared by all targets.
			for d = 1:numel(setCfg.distractorDims)
				dim = setCfg.distractorDims{d};
				if config.distractors && config.randomiseDistractors
					pool = setCfg.distractorPools{d};
					v = pool(randi(numel(pool)));
					stimVals.(dim) = repmat(v, 1, numTargets);
				else
					stimVals.(dim) = setCfg.distractorValues{d};
				end
			end

			% Exemplar for this trial: fixed, or a fresh draw from the dataset
			if config.useExemplars
				exemplar = setCfg.exemplarPool(randi(numel(setCfg.exemplarPool)));
			else
				exemplar = setCfg.exemplar;
			end

			% Randomise positions
			idx = randperm(numTargets);

			% Look up PNGs and assign to targets
			pngs = strings(1, numTargets);
			for t = 1:numTargets
				pngs(t) = lookupPNG(stimVals.shape(t), stimVals.colour(t), ...
					stimVals.appendage(t), stimVals.texture(t), exemplar);
				targets{idx(t)}.filePath = pngs(t);
			end

			% Set correct target
			targets.fixationChoice = idx(correctIdx);

			% Position targets radially around the touch-initiation point
			% (startThings pattern): the angle slots are fixed at equal
			% distance from r.fix, but a fresh shuffle assigns which target
			% occupies which slot each trial.
			posIdx = randperm(numTargets);
			for i = 1:numTargets
				targets{posIdx(i)}.updateXY(xpos(i), ypos(i), true);
			end

			% Log trial parameters
			r.store.stage = r.stage;
			r.store.stageIdx = r.stageIdx;
			r.store.stagesTotal = r.stagesTotal;
			r.store.consecutiveCorrect = r.consecutiveCorrect;
			r.store.stageIncorrect = r.stageIncorrect;
			r.store.stageTrialN = r.stageTrialN;
			r.store.stagesCompleted = r.stagesCompleted;
			r.store.taskFailed = r.taskFailed;
			r.store.criterion = in.criterion;
			r.store.maxIncorrect = in.maxIncorrect;
			r.store.relDim = string(relDim);
			r.store.extraDim = string(extraDim);
			r.store.correctLevel = correctLevel;
			r.store.relLevels = setCfg.relLevels;
			r.store.extraLevels = setCfg.extraLevels;
			r.store.idDim = string(config.idDimension);
			r.store.edDim = string(config.edDimension);
			r.store.setNum = setNum;
			r.store.exemplar = exemplar;
			r.store.numTargets = numTargets;
			r.store.distractors = config.distractors;
			r.store.randomiseDistractors = config.randomiseDistractors;
			r.store.useExemplars = config.useExemplars;
			r.store.distractorDims = strjoin(config.distractorDims, ',');
			r.store.distractorOne = config.distractorOne;
			r.store.distractorTwo = config.distractorTwo;
			r.store.idx = idx;
			r.store.posIdx = posIdx;
			r.store.targetX = xpos(posIdx);   % screen x (deg) per physical target
			r.store.targetY = ypos(posIdx);   % screen y (deg) per physical target
			r.store.correctIdx = correctIdx;
			r.store.stimVals = stimVals;
			r.store.shapeVals = stimVals.shape;
			r.store.colourVals = stimVals.colour;
			r.store.appendageVals = stimVals.appendage;
			r.store.textureVals = stimVals.texture;

			% Trial info — stage, ID/ED dimensions, correct target, distractor values
			r.sampleNames = pngs;
			r.summary = sprintf(...
				"%dD | Trial %d | Stage: %s(%d/%d) | ID: %s | ED: %s | Rel: %s | Correct: T%d(lv%d) | Exemplar: %d | SHA:[%s] CLA:[%s] APA:[%s] TXA:[%s]", ...
				numTargets, r.loopN, upper(r.stage), r.stageIdx, r.stagesTotal, ...
				config.idDimension, config.edDimension, relDim, ...
				idx(correctIdx), correctLevel, exemplar, ...
				strjoin(string(stimVals.shape),","), strjoin(string(stimVals.colour),","), ...
				strjoin(string(stimVals.appendage),","), strjoin(string(stimVals.texture),","));
			r.store.trialInfo = r.summary;
			addMessage(r.tL, r.loopN, GetSecs, [], r.summary, "getsecs", "Experimental-note");

			update(targets);

			%% ==============================Wait for release + initiate
			r = clutil.ensureTouchRelease(r, tM, sM, false);
			[r, dt, r.vblInitT] = clutil.initTouchTrial(r, in, tM, sM, dt);
			disp("===> " + r.summary);
			%% ==============================stimulus presentation
			if matches(string(r.touchInit), "yes")

				r.trialN = r.trialN + 1;
				r.touchResponse = '';

				[x, y] = targets.getFixationPositions;
				tM.updateWindow(x, y, repmat(in.objectSize/1.9, 1, length(x)),...
					repmat(in.doNegation, 1, length(x)), ones(1, length(x)), true(1, length(x)),...
					repmat(in.trialTime, 1, length(x)), ...
					repmat(in.targetHoldTime, 1, length(x)), ones(1, length(x)));

				show(targets);

				if ~isempty(r.sbg); draw(r.sbg); end
				vbl = flip(sM); 
				r.stimOnsetTime = vbl;
				r.vblInit = vbl + r.sv.ifi;
				endTime = r.vblInit + in.trialTime;
				syncTime(tM, r.vblInit);

				while isempty(r.touchResponse) && vbl < endTime
					if ~isempty(r.sbg); draw(r.sbg); end
					draw(targets);
					if in.debug
						drawText(sM, r.summary, 0, sM.screenVals.topInDegrees);
						if ~isempty(tM.x) && ~isempty(tM.y)
							drawText(sM, txt);
							xy = sM.toPixels([tM.x tM.y]);
							Screen('glPoint', sM.win, [1 0 0], xy(1), xy(2), 10);
						end
					end
					vbl = flip(sM);
					% [out, held, heldtime, release, releasing, searching, failed, touch, negation] = testHold
					[r.touchResponse, hld, r.hldtime, rel, ~, ~, fail, tch, negation] = testHold(tM, 'yes', 'no');
					if tch || negation
						r.reactionTime = vbl - r.vblInit;
						r.anyTouch = true;
					end
					if in.debug; txt = sprintf('Response=%i x=%.2f y=%.2f h:%i ht:%i r:%i tch:%i fail:%i neg:%i',...
						r.touchResponse, tM.x, tM.y, hld, r.hldtime, rel, ...
						tch, fail, negation);
					end
					[~,~,c] = KbCheck();
					if c(r.quitKey); r.keepRunning = false; break; end
					if c(r.shotKey); sM.captureScreen; end
				end
			end

			r.vblFinal = GetSecs;
			r.value = hld;

			%% ==============================check result logic
			if matches(r.touchInit, 'no')
				r.result = -5;
			elseif fail || hld == -100 || matches(r.touchResponse, 'no')
				r.result = 0;
			elseif matches(r.touchResponse, 'yes')
				r.result = 1;
			else
				r.result = -1;
			end

			% Determine chosen target from touchManager's windowTouched
			if any(tch) && any(tM.windowTouched > 0) && any(tM.windowTouched <= numTargets)
				chosenTarget = tM.windowTouched;
			else
				chosenTarget = 0;
			end

			%% ==============================store trial outcome
			r.store.result = r.result;
			r.store.anyTouch = r.anyTouch;
			r.store.chosenTarget = chosenTarget;
			r.store.fixationChoice = targets.fixationChoice;
			r.store.correctDim = string(relDim);

			%% ==============================Wait for release + update
			r = clutil.ensureTouchRelease(r, tM, sM, true);
			[dt, r] = clutil.updateTrialResult(in, dt, r, sM, tM, rM, aM);

			%% ==============================IED stage progression
			if r.keepRunning && (r.result == 1 || r.result == 0)
				r.stageTrialN = r.stageTrialN + 1;
				if r.result == 1
					r.consecutiveCorrect = r.consecutiveCorrect + 1;
				else
					r.consecutiveCorrect = 0;
					r.stageIncorrect = r.stageIncorrect + 1;
				end

				if r.consecutiveCorrect >= in.criterion
					r.stagesCompleted = r.stagesCompleted + 1;
					t = sprintf('===> Stage %d/%d [%s] CRITERION MET (%d correct, %d trials, dim=%s)', ...
						r.stageIdx, r.stagesTotal, upper(r.stage), r.consecutiveCorrect, r.stageTrialN, relDim);
					addMessage(r.tL, r.loopN, GetSecs, [], t, "getsecs", "Experimental-note");
					disp(t);

					if r.stageIdx < r.stagesTotal
						r.stageIdx = r.stageIdx + 1;
						r.consecutiveCorrect = 0;
						r.stageIncorrect = 0;
						r.stageTrialN = 0;
						t = sprintf('===> Advancing to stage %d/%d: %s', ...
							r.stageIdx, r.stagesTotal, upper(stages(r.stageIdx)));
						addMessage(r.tL, r.loopN, GetSecs, [], t, "getsecs", "Experimental-note");
						disp(t);
					else
						t = sprintf('===> All %d stages complete. IED %dD task finished.', ...
							r.stagesTotal, numTargets);
						addMessage(r.tL, r.loopN, GetSecs, [], t, "getsecs", "Experimental-note");
						disp(t);
						r.keepRunning = false;
					end

				elseif r.stageIncorrect >= in.maxIncorrect
					r.taskFailed = true;
					t = sprintf('===> Stage %d/%d [%s] FAILED (%d incorrect, %d trials). Task terminated.', ...
						r.stageIdx, r.stagesTotal, upper(r.stage), r.stageIncorrect, r.stageTrialN);
					addMessage(r.tL, r.loopN, GetSecs, [], t, "getsecs", "Experimental-note");
					disp(t);
					r.keepRunning = false;
				end
			end

		end % while keepRunning

		%% ================================shutdown
		clutil.endTask(dt, in, r, sM, tM, rM, aM);

	catch ME
		getReport(ME)
		try writelines(sprintf("Error IEDmorphobes: " + ME.Message), "~/cagelab-start.txt", WriteMode="append"); end
		try if in.remote; r.status.updateStatusToStopped();end;end
		try clutil.broadcastTrial(in, r, dt, false); end
		try if IsLinux && in.remote; system('xset s 600 dpms 600 0 0'); end; end
		try reset(targets); end %#ok<*TRYNC>
		try reset(r.fix); end
		try reset(r.rtarget); end
		try reset(r.sbg); end
		try close(sM); end
		try close(tM); end
		try close(rM); end
		try close(aM); end
		try Priority(0); end
		try ListenChar(0); end
		try RestrictKeysForKbCheck([]); end
		try ShowCursor; end
		rethrow(ME)
	end

end
