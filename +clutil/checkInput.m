function in = checkInput(in)
	if ~exist('in', 'var') || isempty(in)
		in = struct();
	elseif ~isstruct(in)
		error('checkInput:InvalidInput', 'Input must be a struct.');
	end

	pth = fileparts(fileparts(mfilename('fullpath')));

	defaults = struct();
	defaults.density = 70;
	defaults.distance = 30;
	defaults.timeOut = 1;

	defaults.fg = [1 1 0.75];
	defaults.bg = [0.5 0.5 0.5];

	defaults.IP = '127.0.0.1';
	defaults.port = 9012;

	defaults.remote = false;
	defaults.folder = [pth filesep 'resources'];
	defaults.debug = true;
	defaults.dummy = true;
	defaults.reward = false;

	defaults.audio = true;
	defaults.audioDevice = [];
	defaults.audioVolume = 0.2;

	defaults.phase = 1;
	defaults.stimulusType = 'Picture';
	defaults.stimulus = 'Picture';
	defaults.task = 'train';
	defaults.taskType = 'normal';
	defaults.object = 'quaddles';

	defaults.name = 'simulcra';
	defaults.rewardmode = 1;
	defaults.volume = 250;
	defaults.random = 1;
	defaults.screen = 0;
	defaults.smartBackground = true;

	defaults.correctBeep = 3000;
	defaults.incorrectBeep = 400;

	defaults.rewardPort = '/dev/ttyACM0';
	defaults.rewardTime = 200;

	defaults.randomReward = 0;
	defaults.randomProbability = 0.25;

	defaults.nTrialsSample = 10;
	defaults.stepForward = 10;
	defaults.stepPercent = 80;
	defaults.stepBack = 10;

	defaults.doNegation = true;
	defaults.negationBuffer = 2;
	defaults.exclusionZone = [];
	defaults.drainEvents = true;
	defaults.strictMode = true;
	defaults.negateTouch = true;
	defaults.touchDevice = 1;
	defaults.touchDeviceName = 'ILITEK-TP';

	defaults.stimulus = 1;
	defaults.objectSize = 8;
	defaults.objectSep = 12;
	defaults.maxSize = 50;
	defaults.minSize = 4;
	defaults.initPosition = [0 4];
	defaults.initSize = 4;
	defaults.target1Pos = [-5 -5];
	defaults.target2Pos = [5 -5];
	defaults.targetSize = 10;
	defaults.startY = -10;
	defaults.sampleY = -1;
	defaults.distractorY = -1;
	defaults.trialTime = 5;
	defaults.initHoldTime = 0.005;
	defaults.targetHoldTime = 0.005;

	defaults.distractorN = 1;
	defaults.distractorY = 5;
	defaults.sampleTime = 0.5;
	defaults.delayTime = 0.5;

	defaults.zmq = [];
	defaults.alyx = [];
	defaults.useAlyx = false;
	defaults.useBlending = true;
	defaults.disableSync = true;
	defaults.useVulkan = false;
	defaults.command = '';
	defaults.trackID = false;
	defaults.session = struct('researcherName', 'admin', 'labName', 'CognitionPlatform', 'projectName', 'TestTraining', 'subjectName', 'TestSubject');
	defaults.lab = 'CognitionPlatform';
	defaults.sessionURL = '';
	defaults.totalRewards = 10;
	defaults.totalTrials = 10;
	defaults.easyMode = true;
	defaults.ITI = 1;

	% Capture which fields the caller actually supplied BEFORE the generic
	% defaults fill below, so user overrides (e.g. numTargets=4 or
	% edDimension='appendage') are never silently overwritten, while
	% missing fields still receive the task-specific defaults.
	userFields = fieldnames(in);

	fields = fieldnames(defaults);
	for i = 1:numel(fields)
		f = fields{i};
		if ~isfield(in, f) || isempty(in.(f))
			in.(f) = defaults.(f);
		end
	end

	switch in.task
		case {'dmts' 'dnts' 'mts' 'nmts'}

		case 'ied'
			% Classic 'ied' defaults to 2D, but if the caller explicitly
			% sets numTargets=4 then 4D sizing follows.
			n = 2;
			if isfield(in, 'numTargets') && ~isempty(in.numTargets)
				n = in.numTargets;
			end
			if n == 4
				in = applyIedDefaults(in, userFields, 4, 8, 12);
			else
				in = applyIedDefaults(in, userFields, 2, 10, 15);
			end
		case {'ied-2' 'ied-4'}
			if strcmp(in.task, 'ied-2')
				n = 2;
			else
				n = 4;
			end
			in = applyIedDefaults(in, userFields, n, 8, 12);
		otherwise

	end
end

% ===================================================================
%> @brief Apply IED task defaults, but never overwrite a field the caller
%> explicitly supplied (tracked in userFields).
% ===================================================================
function in = applyIedDefaults(in, userFields, numTargets, objectSize, objectSep)
	iedDefaults = struct( ...
		'taskType', 'sd cd cr ids idr eds edr', ...
		'numTargets', numTargets, ...
		'idDimension', 'colour', ...
		'edDimension', 'shape', ...
		'criterion', 6, ...
		'maxIncorrect', 50, ...
		'distractors', numTargets == 4, ...
		'randomiseDistractors', true, ...
		'distractorOne', 0, ...
		'distractorTwo', 0, ...
		'distractorCenterAngle', 270, ...
		'distractorSpreadAngle', 0, ...
		'useExemplars', numTargets == 4, ...
		'objectSize', objectSize, ...
		'objectSep', objectSep, ...
		'sampleY', 0, ...
		'trialTime', 5.0, ...
		'targetHoldTime', 0.2, ...
		'morphobesFolder', '', ...
		'fixSize', 2, ...
		'fixWindow', 4);
	f = fieldnames(iedDefaults);
	for i = 1:numel(f)
		if ~ismember(f{i}, userFields) || isempty(in.(f{i}))
			in.(f{i}) = iedDefaults.(f{i});
		end
	end
end
