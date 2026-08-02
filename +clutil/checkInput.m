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
			in.taskType = 'sd cd cr ids idr eds edr'; % stages run in sequence
			in.numTargets = 2;        % 2D variant: two targets (left/right)
			in.idDimension = 'colour'; % 'shape','colour','appendage','texture' — ID dim
			in.edDimension = 'shape';  % 'shape','colour','appendage','texture' — ED dim
			in.criterion = 6;         % consecutive correct to advance
			in.maxIncorrect = 50;     % incorrect trials on stage before task terminates
			in.objectSize = 10;       % size of objects in degrees
			in.objectSep = 15;        % separation of objects in degrees
			in.sampleY = 0;           % vertical position in degrees
			in.trialTime = 5.0;				% max trial time in seconds
			in.targetHoldTime = 0.2;	% target hold time in seconds
			in.morphobesFolder = '';	% morphobes dataset folder (defaults to resources/morphobes_ied)
			in.fixSize = 2;				% fixation size in degrees
			in.fixWindow = 4;			% fixation window size in degrees
		case {'ied-2' 'ied-4'}
			in.taskType = 'sd cd cr ids idr eds edr'; % stages run in sequence
			in.idDimension = 'colour'; % 'shape','colour','appendage','texture' — ID dim
			in.edDimension = 'shape';  % 'shape','colour','appendage','texture' — ED dim
			in.criterion = 6;         % consecutive correct to advance
			in.maxIncorrect = 50;     % incorrect trials on stage before task terminates
			in.objectSize = 8;        % size of objects in degrees
			in.objectSep = 12;        % separation of objects in degrees
			in.sampleY = 0;           % vertical centre of the 2x2 grid in degrees
			in.trialTime = 5.0;				% max trial time in seconds
			in.targetHoldTime = 0.2;	% target hold time in seconds
			in.morphobesFolder = '';	% morphobes dataset folder (defaults to resources/morphobes)
			in.fixSize = 2;				% fixation size in degrees
			in.fixWindow = 4;			% fixation window size in degrees
			if strcmp(in.task, 'ied-2')
				in.numTargets = 2;    % 2D variant: two targets (left/right)
			else
				in.numTargets = 4;    % 4D variant: four targets in 2x2 grid
			end
		otherwise

	end


end
