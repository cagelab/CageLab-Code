% ========================================================================
%> @class StartIEDMorphobesTest
%> @brief Class-based tests for the unified IED morphobes task entry point.
%>
%> startIEDmorphobes is a monolithic behavioural task: it initialises a
%> screen/audio/reward/touch stack (clutil.initialise), loads a morphobes
%> metadata.csv dataset, builds imageStimulus targets, and runs an IED
%> trial loop until criterion or maxIncorrect is reached. Full execution
%> therefore requires PTB and an X11 display; these are split into:
%>
%>   - CI-safe tests (no PTB): entry-point contract, checkInput defaults,
%>     source-level stage coverage, dimension config validation, and
%>     dataset resolution — every (shape, colour, appendage, texture,
%>     exemplar) combination referenced by the task config must resolve to
%>     exactly one metadata row whose PNG file exists on disk. These run
%>     against a synthetic fixture so they are deterministic, plus against
%>     the real resources/morphobes dataset when it is present.
%>
%>   - hardware tests (PTB window): run the actual task for real with dummy
%>     touch/audio/reward managers, inject Escape via xdotool to terminate
%>     cleanly, and verify data is saved. These need a display — use a real
%>     X server on a rig machine, or Xvfb for GitHub Actions / SSH:
%>       bash tests/runCageLabTestsXvfb.sh
%>
%> Run with:
%>   >> runtests('tests/StartIEDMorphobesTest.m')
%>   >> runtests('tests/StartIEDMorphobesTest.m', '-ExcludeTag', 'hardware')
%>
%> Copyright (c) 2026 Ian Max Andolina — LGPL3, see LICENCE.md
% ========================================================================
classdef StartIEDMorphobesTest < matlab.unittest.TestCase

	properties
		%> Repo root (parent of +cltasks)
		repoRoot char = ''
		%> Path to the real morphobes dataset metadata.csv (may not exist in CI)
		realMetadata char = ''
		%> Synthetic fixture dataset folder (created in TestClassSetup)
		fixtureDir char = ''
	end

	methods (TestClassSetup)
		% ===================================================================
		%> @brief Add opticka + siblings to the path and locate the datasets.
		% ===================================================================
		function setupPath(testCase)
			addOptickaToPath;
			testCase.repoRoot = fileparts(fileparts(which('cltasks.startIEDmorphobes')));
			testCase.realMetadata = fullfile(testCase.repoRoot, ...
				'resources', 'morphobes', 'metadata.csv');
			testCase.fixtureDir = testCase.buildFixture();
		end
	end

	methods (TestClassTeardown)
		% ===================================================================
		%> @brief Remove the synthetic fixture.
		% ===================================================================
		function removeFixture(testCase)
			if ~isempty(testCase.fixtureDir) && isfolder(testCase.fixtureDir)
				rmdir(testCase.fixtureDir, 's');
			end
		end
	end

	% ===================================================================
	% CI-SAFE TESTS (no PTB window required)
	% ===================================================================
	methods (Test, TestTags = {'CI'})

		% ===================================================================
		%> @brief Entry point exists and takes a single input.
		% ===================================================================
		function testEntryPointSignature(testCase)
			name = "cltasks.startIEDmorphobes";
			functionHandle = str2func(name);
			expectedPath = fullfile(testCase.repoRoot, '+cltasks', 'startIEDmorphobes.m');

			verifyEqual(testCase, nargin(functionHandle), 1, 'nargin must be 1');
			verifyEqual(testCase, which(name), expectedPath, 'file location');
		end

		% ===================================================================
		%> @brief Reject invalid input before any hardware initialisation.
		% ===================================================================
		function testRejectsNonStructInput(testCase)
			verifyError(testCase, @() cltasks.startIEDmorphobes(1), ...
				'checkInput:InvalidInput');
		end

		% ===================================================================
		%> @brief checkInput defaults for the classic 'ied' task type.
		% ===================================================================
		function testCheckInputIedDefaults(testCase)
			in = clutil.checkInput(struct('task', 'ied'));

			verifyEqual(testCase, in.numTargets, 2, 'ied defaults to 2D');
			verifyEqual(testCase, string(in.taskType), ...
				"sd cd cr ids idr eds edr", 'default stage sequence');
			verifyEqual(testCase, in.idDimension, 'colour', 'ID dim colour');
			verifyEqual(testCase, in.edDimension, 'shape', 'ED dim shape');
			verifyEqual(testCase, in.criterion, 6, 'criterion default');
			verifyEqual(testCase, in.maxIncorrect, 50, 'maxIncorrect default');
		end

		% ===================================================================
		%> @brief checkInput maps ied-2 to two targets.
		% ===================================================================
		function testCheckInputIed2Defaults(testCase)
			in = clutil.checkInput(struct('task', 'ied-2'));
			verifyEqual(testCase, in.numTargets, 2);
			verifyEqual(testCase, string(in.taskType), ...
				"sd cd cr ids idr eds edr");
		end

		% ===================================================================
		%> @brief checkInput maps ied-4 to four targets.
		% ===================================================================
		function testCheckInputIed4Defaults(testCase)
			in = clutil.checkInput(struct('task', 'ied-4'));
			verifyEqual(testCase, in.numTargets, 4);
			verifyEqual(testCase, string(in.taskType), ...
				"sd cd cr ids idr eds edr");
		end

		% ===================================================================
		%> @brief All eight CANTAB IED stages remain in the task source.
		% ===================================================================
		function testSourceHasAllStages(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			stages = {'sd', 'sr', 'cd', 'cr', 'ids', 'idr', 'eds', 'edr'};
			for stage = stages
				verifyTrue(testCase, contains(source, ['''' stage{1} '''']), ...
					['missing IED stage: ' stage{1}]);
			end
		end

		% ===================================================================
		%> @brief The task supports both 2D and 4D via numTargets.
		% ===================================================================
		function testSourceHasNumTargetsHandling(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			verifyTrue(testCase, contains(source, 'numTargets'));
			verifyTrue(testCase, contains(source, 'iedMorphobesConfig'));
		end

		% ===================================================================
		%> @brief The task uses a 5-parameter PNG lookup against metadata.
		% ===================================================================
		function testSourceHasLookupPNG(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			verifyTrue(testCase, contains(source, 'lookupPNG'));
			verifyTrue(testCase, contains(source, 'metadata.csv'));
			verifyTrue(testCase, contains(source, 'exemplar'));
		end

		% ===================================================================
		%> @brief 2D config: two levels per set for shape + colour.
		% ===================================================================
		function testConfig2DLevels(testCase)
			config = clutil.iedMorphobesConfig(2);

			verifyEqual(testCase, config.dimLevels.shape, [3 6; 1 5; 0 7]);
			verifyEqual(testCase, config.dimLevels.colour, [0 1; 2 4; 6 7]);
			verifyEqual(testCase, config.dimLevels.appendage, zeros(3,2));
			verifyEqual(testCase, config.dimLevels.texture, zeros(3,2));
			verifyEqual(testCase, config.setExemplars, [0 0 0]);
		end

		% ===================================================================
		%> @brief 4D config: four levels per set across all four dimensions.
		% ===================================================================
		function testConfig4DLevels(testCase)
			config = clutil.iedMorphobesConfig(4);

			verifyEqual(testCase, config.dimLevels.shape, [0 1 2 3; 4 5 6 7; 0 1 2 3]);
			verifyEqual(testCase, config.dimLevels.colour, [0 1 2 3; 4 5 6 7; 0 1 2 3]);
			verifyEqual(testCase, config.dimLevels.appendage, repmat(0:3, 3, 1));
			verifyEqual(testCase, config.dimLevels.texture, repmat(0:3, 3, 1));
			verifyEqual(testCase, config.setExemplars, [0 1 2]);
		end

		% ===================================================================
		%> @brief The config helper rejects unsupported target counts.
		% ===================================================================
		function testConfigRejectsInvalidTargets(testCase)
			verifyError(testCase, @() clutil.iedMorphobesConfig(3), ...
				'MATLAB:validators:mustBeMember');
			verifyError(testCase, @() clutil.iedMorphobesConfig(0), ...
				'MATLAB:validators:mustBeMember');
		end

		% ===================================================================
		%> @brief Every 2D config combo resolves in the synthetic fixture.
		% ===================================================================
		function testFixtureResolves2D(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			testCase.verifyConfigResolves(2, meta, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief Every 4D config combo resolves in the synthetic fixture.
		% ===================================================================
		function testFixtureResolves4D(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			testCase.verifyConfigResolves(4, meta, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief The real dataset (when present) satisfies the 2D config.
		%> This is the regression test that would catch a shape/colour level
		%> referenced by the config but missing from the shipped metadata.
		% ===================================================================
		function testRealDatasetResolves2D(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));
			testCase.verifyConfigResolves(2, meta, fileparts(testCase.realMetadata));
		end

		% ===================================================================
		%> @brief The real dataset (when present) satisfies the 4D config.
		% ===================================================================
		function testRealDatasetResolves4D(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));
			testCase.verifyConfigResolves(4, meta, fileparts(testCase.realMetadata));
		end

		% ===================================================================
		%> @brief The task's default dataset folder exists (when resources
		%> are checked out) and has the expected schema.
		% ===================================================================
		function testDefaultDatasetFolderExists(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));

			verifyTrue(testCase, ismember('shape_level', meta.Properties.VariableNames));
			verifyTrue(testCase, ismember('colour_level', meta.Properties.VariableNames));
			verifyTrue(testCase, ismember('appendage_level', meta.Properties.VariableNames));
			verifyTrue(testCase, ismember('texture_level', meta.Properties.VariableNames));
			verifyTrue(testCase, ismember('exemplar', meta.Properties.VariableNames));
			verifyTrue(testCase, ismember('png_path', meta.Properties.VariableNames));
		end
	end

	% ===================================================================
	% HARDWARE TESTS (need PTB window; real X or Xvfb)
	% ===================================================================
	methods (Test, TestTags = {'hardware'})

		% ===================================================================
		%> @brief Run the real 2D task with dummy managers, terminate via
		%> the quit key injected with xdotool, and check data is saved.
		% ===================================================================
		function testTaskRunsDirectly2D(testCase)
			testCase.runTaskToQuit(2);
		end

		% ===================================================================
		%> @brief Run the real 4D task with dummy managers, terminate via
		%> the quit key injected with xdotool, and check data is saved.
		% ===================================================================
		function testTaskRunsDirectly4D(testCase)
			testCase.runTaskToQuit(4);
		end
	end

	% ===================================================================
	% PRIVATE HELPERS
	% ===================================================================
	methods (Access = private)

		% ===================================================================
		%> @brief Build a synthetic morphobes dataset covering both configs.
		% ===================================================================
		function fixture = buildFixture(testCase)
			fixture = tempname;
			mkdir(fixture);
			pngDir = fullfile(fixture, 'png');
			mkdir(pngDir);
			% one shared tiny PNG; all metadata rows point at it
			pngPath = fullfile(pngDir, 'microbe_00001.png');
			imwrite(randi(255, 8, 8, 3, 'uint8'), pngPath);

			% full 4D-style grid: shapes 0-7 x colours 0-7 x appendage 0-3 x
			% texture 0-3 x exemplars 0-2. This covers both the 2D and 4D
			% configurations used by iedMorphobesConfig.
			shapes = 0:7; colours = 0:7; app = 0:3; tex = 0:3; ex = 0:2;
			n = numel(shapes) * numel(colours) * numel(app) * numel(tex) * numel(ex);
			shapeLv = zeros(n,1); colourLv = zeros(n,1);
			appLv = zeros(n,1); texLv = zeros(n,1); exLv = zeros(n,1);
			pngs = strings(n,1);
			idx = 0;
			for ii = shapes
				for jj = colours
					for kk = app
						for ll = tex
							for mm = ex
								idx = idx + 1;
								shapeLv(idx) = ii; colourLv(idx) = jj;
								appLv(idx) = kk; texLv(idx) = ll; exLv(idx) = mm;
								pngs(idx) = "png/microbe_00001.png";
							end
						end
					end
				end
			end
			T = table(shapeLv, colourLv, appLv, texLv, exLv, pngs, ...
				'VariableNames', {'shape_level','colour_level', ...
				'appendage_level','texture_level','exemplar','png_path'});
			writetable(T, fullfile(fixture, 'metadata.csv'));
		end

		% ===================================================================
		%> @brief Read metadata.csv using the same options as the task.
		% ===================================================================
		function meta = readMetadata(~, folder)
			meta = readtable(fullfile(folder, 'metadata.csv'), ...
				'VariableNamingRule', 'preserve', 'TextType', 'string');
		end

		% ===================================================================
		%> @brief Verify every config combo resolves to exactly one metadata
		%> row whose PNG exists, including the neutral (shape 0) SD/SR case.
		% ===================================================================
		function verifyConfigResolves(testCase, numTargets, meta, folder)
			config = clutil.iedMorphobesConfig(numTargets);
			allDims = {'shape','colour','appendage','texture'};
			for setN = 1:3
				exemplar = config.setExemplars(setN);
				for t = 1:numTargets
					s = config.dimLevels.shape(setN, t);
					c = config.dimLevels.colour(setN, t);
					a = config.dimLevels.appendage(setN, t);
					tx = config.dimLevels.texture(setN, t);
					testCase.verifyResolves(meta, folder, s, c, a, tx, exemplar, ...
						sprintf('set %d target %d', setN, t));
				end
				% SD/SR use neutral distractors (all non-relevant dims = 0);
				% shape 0 must exist paired with every set colour.
				if numTargets == 2
					for c = config.dimLevels.colour(setN, :)
						testCase.verifyResolves(meta, folder, 0, c, 0, 0, exemplar, ...
							sprintf('set %d neutral shape 0 colour %d', setN, c));
					end
				end
			end
		end

		% ===================================================================
		%> @brief Single lookup + file-exists check.
		% ===================================================================
		function verifyResolves(testCase, meta, folder, s, c, a, tx, ex, label)
			mask = meta.shape_level == s & meta.colour_level == c & ...
				meta.appendage_level == a & meta.texture_level == tx & ...
				meta.exemplar == ex;
			verifyEqual(testCase, sum(mask), 1, ...
				[sprintf('lookup must be unique (%s): shape=%d colour=%d app=%d tex=%d ex=%d', ...
				label, s, c, a, tx, ex)]);
			if sum(mask) == 1
				png = char(meta.png_path(mask));
				verifyTrue(testCase, isfile(fullfile(folder, png)), ...
					['PNG exists for ' label ': ' png]);
			end
		end

		% ===================================================================
		%> @brief Build a minimal task input struct for a hardware run.
		% ===================================================================
		function in = makeTaskInput(testCase, numTargets)
			in = struct();
			if numTargets == 4
				in.task = 'ied-4';
			else
				in.task = 'ied-2';
			end
			in.numTargets = numTargets;
			in.taskType = 'sd cd cr ids idr eds edr';
			in.criterion = 6;
			in.maxIncorrect = 50;
			in.objectSize = 8;
			in.objectSep = 12;
			in.sampleY = 0;
			in.trialTime = 1.5;
			in.targetHoldTime = 0.05;
			in.initHoldTime = 0.05;
			in.morphobesFolder = testCase.fixtureDir;
			% dummy managers: no real touch/audio/reward hardware needed
			in.dummy = true;
			in.audio = false;
			in.reward = false;
			in.debug = true;    % windowed debug mode (kPsychGUIWindow)
			in.screen = 0;
			in.disableSync = true;
			in.useVulkan = false;
			in.remote = false;
			in.useAlyx = false;
			in.smartBackground = false;
			in.highPriority = false;
			in.verbose = false;
		end

		% ===================================================================
		%> @brief Run the task for real; inject Escape via xdotool to end it,
		%> and verify a data file was saved by endTask.
		% ===================================================================
		function runTaskToQuit(testCase, numTargets)
			% Requires a display (real X on a rig, or Xvfb in CI/SSH) and
			% xdotool to inject the quit key.
			assumeTrue(testCase, ~isempty(getenv('DISPLAY')) || isunix, ...
				'No X display available; use runCageLabTestsXvfb.sh or a rig machine');
			[status, ~] = system('command -v xdotool');
			assumeTrue(testCase, status == 0, 'xdotool required for hardware test');
			assumeTrue(testCase, testCase.canOpenWindow(), ...
				'PTB cannot open a window in this environment');

			in = testCase.makeTaskInput(numTargets);
			lastTaskRun = fullfile(getenv('HOME'), 'lastTaskRun.mat');
			if isfile(lastTaskRun); delete(lastTaskRun); end

			% inject Escape twice (4s and 8s) so the loop terminates cleanly
			cmd = sprintf('(sleep 4; xdotool key Escape; sleep 4; xdotool key Escape) &');
			system(cmd);

			err = '';
			try
				cltasks.startIEDmorphobes(in);
			catch ME
				err = ME.message;
			end
			verifyEmpty(testCase, err, ['task ran without error: ' err]);
			verifyTrue(testCase, isfile(lastTaskRun), ...
				'endTask saved data to ~/lastTaskRun.mat');
		end

		% ===================================================================
		%> @brief Try to open a small PTB window to confirm the environment
		%> can actually run hardware tests.
		% ===================================================================
		function ok = canOpenWindow(testCase)
			ok = false;
			try
				PsychDefaultSetup(2);
				s = Screen('Screens');
				if isempty(s); return; end
				[w, ~] = Screen('OpenWindow', 0, [0.5 0.5 0.5], [0 0 200 200]);
				Screen('Flip', w);
				Screen('CloseAll');
				ok = true;
			catch ME
				fprintf('canOpenWindow: %s\n', ME.message);
				try Screen('CloseAll'); catch, end
			end
		end
	end
end
