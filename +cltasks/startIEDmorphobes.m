function startIEDmorphobes(in)
	% startIEDmorphobes(in)
	% Start an Intra-Dimensional / Extra-Dimensional Set Shifting Task
	% (CANTAB derivative) using morphobes parametric microorganism stimuli.
	%
	% This unified function supports both 2-target (2D) and 4-target (4D)
	% configurations via the in.numTargets parameter:
	%   numTargets = 2 — two targets (left/right), colour is ID, shape is ED.
	%                 Uses the unified morphobes dataset (shape + colour levels).
	%   numTargets = 4 — four targets in a 2x2 grid, four dimensions (shape,
	%                 colour, appendage, texture) with configurable ID/ED
	%                 assignment. Uses the unified morphobes dataset.
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
	%   in.objectSize = 8;        % size of objects in degrees
	%   in.objectSep = 12;        % separation of objects in degrees
	%   in.sampleY = 0;           % vertical centre of the grid in degrees
	%   in.trialTime = 5.0;       % max trial time in seconds
	%   in.targetHoldTime = 0.2;  % target hold time in seconds
	%   in.morphobesFolder = '';  % morphobes dataset folder
	%                              %   defaults to resources/morphobes
	%                              %   (legacy: morphobes_ied / morphobes_ied4d)
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

	bgName = 'redmarbleA.jpg';
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

		%% ============================dimension level configuration
		% Shared config helper so tests can validate levels against the
		% dataset metadata without running the task.
		config = clutil.iedMorphobesConfig(numTargets);
		dimLevels = config.dimLevels;
		setExemplars = config.setExemplars;

		% Warn if the ED dimension is constant in the final set (EDS/EDR):
		% the 2D config only varies shape+colour, so appendage/texture ED
		% shifts are only meaningful with numTargets=4.
		if numel(unique(dimLevels.(in.edDimension)(3, :))) < 2
			warning('startIEDmorphobes:ConstantEDDimension', ...
				'edDimension ''%s'' has constant levels in set 3 (EDS/EDR). For a meaningful ED shift use numTargets=4 (4D config varies all dimensions).', ...
				in.edDimension);
		end

		%% ============================create targets in grid
		targetL = imageStimulus('size', in.objectSize, 'randomiseSelection', false);
		targets = metaStimulus('stimuli', repmat({targetL}, 1, numTargets));
		for i = 1:numTargets
			targets{i} = clone(targetL);
		end

		% Grid positions: 1x2 (left/right) or 2x2
		if numTargets == 4
			posX = [-in.objectSep/2, in.objectSep/2, -in.objectSep/2, in.objectSep/2];
			posY = [in.objectSep/2, in.objectSep/2, -in.objectSep/2, -in.objectSep/2];
		else
			posX = [-in.objectSep/2, in.objectSep/2];
			posY = [0, 0];
		end
		for i = 1:numTargets
			targets{i}.xPosition = posX(i);
			targets{i}.yPosition = posY(i) + in.sampleY;
		end
		targets.stimulusSets{1} = 1:numTargets;
		targets.fixationChoice = 1;

		%% ============================setup
		setup(r.fix, sM);
		setup(targets, sM);
		hide(targets);
		targets.edit(1:numTargets, 'colourOut', [1 1 1]);

		in.doNegation = true;

		%% ============================validate all stages
		validTaskTypes = {'sd','sr','cd','cr','ids','idr','eds','edr'};
		for i = 1:length(stages)
			if ~ismember(stages(i), validTaskTypes)
				warning('Unknown task type %s. Defaulting to SD.', stages(i));
				stages(i) = 'sd';
			end
		end
		in.stages = stages;

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
			fail = false; hld = false;

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

			% Relevant dimension: ID for sets 1-2, ED for set 3
			if setNum <= 2
				relDim = in.idDimension;
			else
				relDim = in.edDimension;
			end

			% Correct value index: 1 for non-reversal, 2 for reversal
			if ismember(r.stage, {'sr','cr','idr','edr'})
				correctIdx = 2;
			else
				correctIdx = 1;
			end

			% Distractor behavior: constant (SD/SR) or randomised (CD+)
			distractorsConstant = ismember(r.stage, {'sd','sr'});

			% Exemplar for this set
			exemplar = setExemplars(setNum);

			% Distractor dimensions
			allDims = {'shape','colour','appendage','texture'};
			distDims = allDims(~strcmp(allDims, relDim));

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
			r.store.idDim = string(in.idDimension);
			r.store.edDim = string(in.edDimension);
			r.store.setNum = setNum;
			r.store.exemplar = exemplar;
			r.store.distractorsConstant = distractorsConstant;
			r.store.numTargets = numTargets;

			%% ==============================select stimuli for targets
			% Relevant dimension: unique values from current set
			relLevels = dimLevels.(relDim)(setNum, :);

			% Stimulus values for targets (column = target)
			stimVals = struct('shape', zeros(1, numTargets), 'colour', zeros(1, numTargets), ...
				'appendage', zeros(1, numTargets), 'texture', zeros(1, numTargets));
			stimVals.(relDim) = relLevels;

			% Set distractor values
			if distractorsConstant
				for d = 1:length(distDims)
					stimVals.(distDims{d})(:) = 0;
				end
			else
				for d = 1:length(distDims)
					availLv = dimLevels.(distDims{d})(setNum, :);
					stimVals.(distDims{d}) = availLv(randperm(numTargets));
				end
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

			% Log stimulus config
			r.store.idx = idx;
			r.store.correctIdx = correctIdx;
			r.store.stimVals = stimVals;
			r.store.shapeVals = stimVals.shape;
			r.store.colourVals = stimVals.colour;
			r.store.appendageVals = stimVals.appendage;
			r.store.textureVals = stimVals.texture;

			% Trial info
			r.sampleNames = pngs;
			r.summary = sprintf(...
				"%dD | Stage: %s(%d/%d) | RelDim: %s | Excplr: %d | Correct: %d | SHA:%s CLA:%s APA:%s TXA:%s", ...
				numTargets, upper(r.stage), r.stageIdx, r.stagesTotal, ...
				relDim, exemplar, idx(correctIdx), ...
				strjoin(string(stimVals.shape),","), strjoin(string(stimVals.colour),","), ...
				strjoin(string(stimVals.appendage),","), strjoin(string(stimVals.texture),","));

			showSet(targets, 1);
			update(targets);

			%% ==============================Wait for release + initiate
			r = clutil.ensureTouchRelease(r, tM, sM, false);
			[r, dt, r.vblInitT] = clutil.initTouchTrial(r, in, tM, sM, dt);

			%% ==============================stimulus presentation
			if matches(string(r.touchInit), "yes")

				r.trialN = r.trialN + 1;
				r.touchResponse = '';

				[x, y] = targets.getFixationPositions;
				tM.updateWindow(x, y, repmat(in.objectSize/1.9, 1, length(x)),...
					repmat(in.doNegation, 1, length(x)), ones(1, length(x)), true(1, length(x)),...
					repmat(in.trialTime, 1, length(x)), ...
					repmat(in.targetHoldTime, 1, length(x)), ones(1, length(x)));

				if ~isempty(r.sbg); draw(r.sbg); end
				vbl = flip(sM);
				r.stimOnsetTime = vbl;
				r.vblInit = vbl + r.sv.ifi;
				syncTime(tM, r.vblInit);

				while isempty(r.touchResponse) && vbl <= (r.vblInit + in.trialTime)
					if ~isempty(r.sbg); draw(r.sbg); end
					draw(targets);
					if in.debug && ~isempty(tM.x) && ~isempty(tM.y)
						drawText(sM, txt);
						xy = sM.toPixels([tM.x tM.y]);
						Screen('glPoint', sM.win, [1 0 0], xy(1), xy(2), 10);
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
			if tch && tM.windowTouched > 0 && tM.windowTouched <= numTargets
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
