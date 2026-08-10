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
%>     source-level stage coverage, the clutil.iedMorphobesConfig
%>     settings/metaTable-driven per-set specification (intra + extra
%>     dimension levels, distractor policy, exemplars), and dataset
%>     resolution — every morphobe sample the task can present must
%>     resolve to exactly one metadata row whose PNG file exists on disk.
%>     These run against a synthetic fixture (using the REAL dataset level
%>     encodings, e.g. shape 0,1,2,4,7,8,11 — not contiguous) so they are
%>     deterministic, plus against the real resources/morphobes dataset
%>     when it is present.
%>
%>   - hardware tests (PTB window): run the actual task for real with dummy
%>     touch/audio/reward managers, inject Escape via xdotool to terminate
%>     cleanly, and verify data is saved. These need a display — use a real
%>     X server on a rig machine, or Xvfb for GitHub Actions / SSH:
%>       bash tests/runCageLabTestsXvfb.sh
%>
%> Run with:
%>   >> runtests('tests/StartIEDMorphobesTest.m')
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
		%> @brief checkInput defaults for the classic 'ied' task type (2D).
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
			verifyFalse(testCase, in.distractors, ...
				'2D defaults to neutral distractors (classic simple discrimination)');
			verifyTrue(testCase, in.randomiseDistractors, ...
				'randomiseDistractors defaults true');
			verifyEqual(testCase, in.distractorOne, 0, 'distractorOne default');
			verifyEqual(testCase, in.distractorTwo, 0, 'distractorTwo default');
			verifyFalse(testCase, in.useExemplars, '2D defaults to no exemplars');
		end

		% ===================================================================
		%> @brief checkInput maps ied-2 to two targets.
		% ===================================================================
		function testCheckInputIed2Defaults(testCase)
			in = clutil.checkInput(struct('task', 'ied-2'));
			verifyEqual(testCase, in.numTargets, 2);
			verifyEqual(testCase, string(in.taskType), ...
				"sd cd cr ids idr eds edr");
			verifyFalse(testCase, in.distractors);
			verifyFalse(testCase, in.useExemplars);
		end

		% ===================================================================
		%> @brief checkInput maps ied-4 to four targets (4D compound defaults).
		% ===================================================================
		function testCheckInputIed4Defaults(testCase)
			in = clutil.checkInput(struct('task', 'ied-4'));
			verifyEqual(testCase, in.numTargets, 4);
			verifyEqual(testCase, string(in.taskType), ...
				"sd cd cr ids idr eds edr");
			verifyTrue(testCase, in.distractors, ...
				'4D defaults to shown (compound) distractors');
			verifyTrue(testCase, in.randomiseDistractors);
			verifyTrue(testCase, in.useExemplars, ...
				'4D defaults to per-trial exemplars');
		end

		% ===================================================================
		%> @brief User-supplied numTargets must NOT be overwritten by the
		%> task defaults (regression: task='ied' + numTargets=4 previously
		%> collapsed to two targets).
		% ===================================================================
		function testCheckInputIedRespectsUserNumTargets(testCase)
			in = clutil.checkInput(struct('task', 'ied', 'numTargets', 4));
			verifyEqual(testCase, in.numTargets, 4, ...
				'numTargets=4 with task=ied must be preserved');
			verifyEqual(testCase, in.objectSize, 8, ...
				'4D sizing applies when numTargets=4');
			verifyTrue(testCase, in.distractors, ...
				'4D distractor defaults apply when numTargets=4');

			in2 = clutil.checkInput(struct('task', 'ied', 'numTargets', 2));
			verifyEqual(testCase, in2.numTargets, 2);
			verifyEqual(testCase, in2.objectSize, 10, ...
				'2D sizing applies when numTargets=2');
			verifyFalse(testCase, in2.distractors, ...
				'2D distractor defaults apply when numTargets=2');
		end

		% ===================================================================
		%> @brief User-supplied id/ed dimensions must NOT be overwritten by
		%> the task defaults (regression: edDimension='appendage' previously
		%> collapsed to shape).
		% ===================================================================
		function testCheckInputIedRespectsUserDimensions(testCase)
			in = clutil.checkInput(struct('task', 'ied', ...
				'edDimension', 'appendage', 'idDimension', 'texture'));
			verifyEqual(testCase, in.edDimension, 'appendage', ...
				'edDimension=appendage must be preserved');
			verifyEqual(testCase, in.idDimension, 'texture', ...
				'idDimension=texture must be preserved');
		end

		% ===================================================================
		%> @brief User-supplied criterion/maxIncorrect must be preserved.
		% ===================================================================
		function testCheckInputIedRespectsUserCriteria(testCase)
			in = clutil.checkInput(struct('task', 'ied', ...
				'criterion', 2, 'maxIncorrect', 3));
			verifyEqual(testCase, in.criterion, 2);
			verifyEqual(testCase, in.maxIncorrect, 3);
		end

		% ===================================================================
		%> @brief User-supplied distractor/exemplar parameters must NOT be
		%> overwritten by the task defaults.
		% ===================================================================
		function testCheckInputIedRespectsUserDistractorParams(testCase)
			in = clutil.checkInput(struct('task', 'ied-4', ...
				'distractors', false, 'randomiseDistractors', false, ...
				'distractorOne', 3, 'distractorTwo', 2, 'useExemplars', false));
			verifyFalse(testCase, in.distractors, ...
				'distractors=false must be preserved');
			verifyFalse(testCase, in.randomiseDistractors, ...
				'randomiseDistractors=false must be preserved');
			verifyEqual(testCase, in.distractorOne, 3, ...
				'distractorOne must be preserved');
			verifyEqual(testCase, in.distractorTwo, 2, ...
				'distractorTwo must be preserved');
			verifyFalse(testCase, in.useExemplars, ...
				'useExemplars=false must be preserved');
		end

		% ===================================================================
		%> @brief clutil.normaliseDimension handles plurals, case and
		%> whitespace variants of the four morphobes dimensions.
		% ===================================================================
		function testNormaliseDimension(testCase)
			verifyEqual(testCase, clutil.normaliseDimension('appendage'), 'appendage');
			verifyEqual(testCase, clutil.normaliseDimension('appendages'), 'appendage');
			verifyEqual(testCase, clutil.normaliseDimension('Appendage'), 'appendage');
			verifyEqual(testCase, clutil.normaliseDimension('APPENDAGES'), 'appendage');
			verifyEqual(testCase, clutil.normaliseDimension('shape'), 'shape');
			verifyEqual(testCase, clutil.normaliseDimension('shapes'), 'shape');
			verifyEqual(testCase, clutil.normaliseDimension('colour'), 'colour');
			verifyEqual(testCase, clutil.normaliseDimension('colours'), 'colour');
			verifyEqual(testCase, clutil.normaliseDimension('texture'), 'texture');
			verifyEqual(testCase, clutil.normaliseDimension('textures'), 'texture');
			verifyEqual(testCase, clutil.normaliseDimension('  shape  '), 'shape');
			verifyEqual(testCase, clutil.normaliseDimension('sound'), '', ...
				'invalid dimension returns empty');
			verifyEqual(testCase, clutil.normaliseDimension(''), '', ...
				'empty returns empty');
		end

		% ===================================================================
		%> @brief The task source uses the metaTable-driven config helper and
		%> the new distractor/exemplar parameters.
		% ===================================================================
		function testSourceUsesConfigHelper(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			verifyTrue(testCase, contains(source, 'clutil.normaliseDimension'));
			verifyTrue(testCase, contains(source, 'iedMorphobesConfig(in, metaTable)'), ...
				'config must be built from settings + metadata');
			verifyTrue(testCase, contains(source, 'setCfg = config.sets(setNum)'), ...
				'trial loop must pull the per-set specification');
			verifyTrue(testCase, contains(source, 'setCfg.relLevels'));
		end

		% ===================================================================
		%> @brief The task source implements all five distractor/exemplar
		%> parameters.
		% ===================================================================
		function testSourceHasDistractorParameters(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			params = {'distractors', 'randomiseDistractors', ...
				'distractorOne', 'distractorTwo', 'useExemplars'};
			for p = params
				verifyTrue(testCase, contains(source, p{1}), ...
					['missing parameter in source: ' p{1}]);
			end
		end

		% ===================================================================
		%> @brief The task stage parser accepts the GUI's bracket/quoted
		%> taskType format: '[ "sd" "sr" ... ]'.
		% ===================================================================
		function testSourceParsesGuiTaskType(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			verifyTrue(testCase, contains(source, '''['''), ...
				'source strips brackets from taskType');
			verifyTrue(testCase, contains(source, 'replace(stages'));
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
		%> @brief The task uses a 5-parameter PNG lookup against metadata.
		% ===================================================================
		function testSourceHasLookupPNG(testCase)
			source = fileread(which('cltasks.startIEDmorphobes'));
			verifyTrue(testCase, contains(source, 'lookupPNG'));
			verifyTrue(testCase, contains(source, 'metadata.csv'));
			verifyTrue(testCase, contains(source, 'exemplar'));
		end

		% ===================================================================
		%> @brief The config helper rejects unsupported target counts.
		% ===================================================================
		function testConfigRejectsInvalidTargets(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			verifyError(testCase, @() clutil.iedMorphobesConfig(struct('numTargets', 3), meta), ...
				'iedMorphobesConfig:InvalidNumTargets');
			verifyError(testCase, @() clutil.iedMorphobesConfig(struct('numTargets', 0), meta), ...
				'iedMorphobesConfig:InvalidNumTargets');
		end

		% ===================================================================
		%> @brief The config rejects identical ID/ED dimensions.
		% ===================================================================
		function testConfigRejectsSameDimensions(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.idDimension = 'colour';
			in.edDimension = 'colour';
			verifyError(testCase, @() clutil.iedMorphobesConfig(in, meta), ...
				'iedMorphobesConfig:SameDimensions');
		end

		% ===================================================================
		%> @brief 2D config structure: colour is ID (sets 1-2), shape is ED
		%> (set 3), non-relevant dims neutral, exemplar fixed at 0.
		% ===================================================================
		function testConfig2DStructure(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(2);
			config = clutil.iedMorphobesConfig(in, meta);

			verifyEqual(testCase, config.numTargets, 2);
			verifyEqual(testCase, config.idDimension, 'colour');
			verifyEqual(testCase, config.edDimension, 'shape');
			verifyFalse(testCase, config.distractors);
			verifyFalse(testCase, config.useExemplars);
			verifyEqual(testCase, sort(config.distractorDims), ...
				{'appendage', 'texture'}, 'non-ID/ED dims are the distractors');

			for s = 1:3
				setCfg = config.sets(s);
				if s <= 2
					verifyEqual(testCase, setCfg.relDim, 'colour', ...
						['ID dim relevant in set ' num2str(s)]);
				else
					verifyEqual(testCase, setCfg.relDim, 'shape', ...
						'ED dim relevant in set 3');
				end
				verifyEqual(testCase, numel(setCfg.relLevels), 2, ...
					'two levels per set in 2D');
				verifyTrue(testCase, numel(unique(setCfg.relLevels)) == 2, ...
					'relLevels must be distinct');
				verifyEqual(testCase, setCfg.exemplar, 0, ...
					'exemplar fixed at 0 when useExemplars=false');
				for k = 1:numel(setCfg.nonRelevantDims)
					verifyEqual(testCase, setCfg.distractorValues{k}, [0 0], ...
						['neutral distractor values in set ' num2str(s)]);
				end
			end
		end

		% ===================================================================
		%> @brief 4D config structure: all four dimensions active, distractor
		%> pools from the dataset, per-trial exemplar pool.
		% ===================================================================
		function testConfig4DStructure(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			config = clutil.iedMorphobesConfig(in, meta);

			verifyEqual(testCase, config.numTargets, 4);
			verifyTrue(testCase, config.distractors);
			verifyTrue(testCase, config.randomiseDistractors);
			verifyTrue(testCase, config.useExemplars);

			for s = 1:3
				setCfg = config.sets(s);
				verifyEqual(testCase, numel(setCfg.relLevels), 4, ...
					'four levels per set in 4D');
				verifyTrue(testCase, numel(unique(setCfg.relLevels)) == 4, ...
					'relLevels must be distinct');
				verifyEqual(testCase, numel(setCfg.nonRelevantDims), 3, ...
					'three non-relevant dims per set (incl. the other ID/ED dim)');
				for k = 1:numel(setCfg.nonRelevantDims)
					dim = setCfg.nonRelevantDims{k};
					verifyEqual(testCase, setCfg.distractorPools{k}, ...
						config.available.(dim), ...
						['distractor pool must be the dataset levels for ' dim]);
				end
				verifyEqual(testCase, setCfg.exemplarPool, [0 1 2 3], ...
					'exemplar pool from dataset');
			end
		end

		% ===================================================================
		%> @brief The config derives levels from the metaTable, so it must
		%> match the actual (non-contiguous) dataset level encodings. This is
		%> the regression test for the old hardcoded matrices that referenced
		%> levels missing from the procedural dataset (e.g. shape 3/5/6,
		%> colour 4/5, appendage 3).
		% ===================================================================
		function testConfigAvailableMatchesDataset(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			config = clutil.iedMorphobesConfig(in, meta);

			verifyEqual(testCase, config.available.shape, [0 1 2 4 7 8 11], ...
				'shape levels match the dataset catalogue');
			verifyEqual(testCase, config.available.colour, [0 1 2 3 6 7], ...
				'colour levels match the dataset catalogue');
			verifyEqual(testCase, config.available.appendage, [0 1 2 4 5], ...
				'appendage levels match the dataset catalogue');
			verifyEqual(testCase, config.available.texture, [0 1 2 3 4], ...
				'texture levels match the dataset catalogue');
		end

		% ===================================================================
		%> @brief distractors=false holds every non-relevant dimension
		%> neutral, regardless of the fixed values.
		% ===================================================================
		function testConfigDistractorsOff(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.distractors = false;
			in.randomiseDistractors = true; % must be ignored
			in.distractorOne = 2;
			in.distractorTwo = 1;
			config = clutil.iedMorphobesConfig(in, meta);

			for s = 1:3
				setCfg = config.sets(s);
				for k = 1:numel(setCfg.nonRelevantDims)
					verifyEqual(testCase, setCfg.distractorValues{k}, ...
						zeros(1, 4), ['neutral distractors in set ' num2str(s)]);
					verifyTrue(testCase, isempty(setCfg.distractorPools{k}), ...
						'no pools when distractors=false');
				end
			end
		end

		% ===================================================================
		%> @brief distractors=true + randomiseDistractors=false uses the
		%> fixed distractorOne/distractorTwo values for the two persistent
		%> distractors and neutral 0 for the temporarily irrelevant ID/ED dim.
		% ===================================================================
		function testConfigDistractorsFixed(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.distractors = true;
			in.randomiseDistractors = false;
			in.distractorOne = 2;
			in.distractorTwo = 1;
			config = clutil.iedMorphobesConfig(in, meta);

			verifyEqual(testCase, config.distractorDims, {'appendage', 'texture'});
			for s = 1:3
				setCfg = config.sets(s);
				for k = 1:numel(setCfg.nonRelevantDims)
					dim = setCfg.nonRelevantDims{k};
					if strcmp(dim, 'appendage')
						verifyEqual(testCase, setCfg.distractorValues{k}, [2 2 2 2], ...
							'first persistent distractor uses distractorOne');
					elseif strcmp(dim, 'texture')
						verifyEqual(testCase, setCfg.distractorValues{k}, [1 1 1 1], ...
							'second persistent distractor uses distractorTwo');
					else
						verifyEqual(testCase, setCfg.distractorValues{k}, [0 0 0 0], ...
							['temporarily irrelevant ID/ED dim neutral: ' dim]);
					end
					verifyTrue(testCase, isempty(setCfg.distractorPools{k}), ...
						'no pools when randomiseDistractors=false');
				end
			end
		end

		% ===================================================================
		%> @brief distractors=true + randomiseDistractors=true exposes the
		%> full dataset level pools for every non-relevant dimension.
		% ===================================================================
		function testConfigDistractorsRandom(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			config = clutil.iedMorphobesConfig(in, meta);

			for s = 1:3
				setCfg = config.sets(s);
				for k = 1:numel(setCfg.nonRelevantDims)
					dim = setCfg.nonRelevantDims{k};
					verifyEqual(testCase, setCfg.distractorPools{k}, ...
						config.available.(dim));
				end
			end
		end

		% ===================================================================
		%> @brief useExemplars=false fixes the exemplar; the config warns and
		%> clamps when the fixed distractor value is not in the dataset.
		% ===================================================================
		function testConfigClampsInvalidDistractorValue(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.distractors = true;
			in.randomiseDistractors = false;
			in.distractorOne = 99; % not a valid appendage level
			verifyWarning(testCase, ...
				@() clutil.iedMorphobesConfig(in, meta), ...
				'iedMorphobesConfig:InvalidDistractorValue');
			config = clutil.iedMorphobesConfig(in, meta);
			verifyTrue(testCase, ismember(config.distractorOne, config.available.appendage), ...
				'clamped value must exist in the dataset');
		end

		% ===================================================================
		%> @brief randomiseDistractors is ignored (with a warning) when
		%> distractors=false.
		% ===================================================================
		function testConfigWarnsRandomiseIgnored(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.distractors = false;
			in.randomiseDistractors = true;
			verifyWarning(testCase, ...
				@() clutil.iedMorphobesConfig(in, meta), ...
				'iedMorphobesConfig:RandomiseIgnored');
		end

		% ===================================================================
		%> @brief Every 2D config sample resolves in the synthetic fixture.
		% ===================================================================
		function testFixtureResolves2D(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			testCase.verifyConfigResolves(testCase.makeInput(2), meta, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief Every 4D config sample resolves in the synthetic fixture.
		% ===================================================================
		function testFixtureResolves4D(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			testCase.verifyConfigResolves(testCase.makeInput(4), meta, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief Every 4D fixed-distractor sample resolves in the fixture.
		% ===================================================================
		function testFixtureResolves4DFixed(testCase)
			meta = testCase.readMetadata(testCase.fixtureDir);
			in = testCase.makeInput(4);
			in.randomiseDistractors = false;
			in.distractorOne = 2;
			in.distractorTwo = 1;
			testCase.verifyConfigResolves(in, meta, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief The real dataset (when present) satisfies the 2D config.
		%> This is the regression test that would catch a level referenced by
		%> the config but missing from the shipped metadata.
		% ===================================================================
		function testRealDatasetResolves2D(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));
			testCase.verifyConfigResolves(testCase.makeInput(2), meta, fileparts(testCase.realMetadata));
		end

		% ===================================================================
		%> @brief The real dataset (when present) satisfies the 4D config.
		% ===================================================================
		function testRealDatasetResolves4D(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));
			testCase.verifyConfigResolves(testCase.makeInput(4), meta, fileparts(testCase.realMetadata));
		end

		% ===================================================================
		%> @brief The real dataset satisfies the 4D fixed-distractor config.
		% ===================================================================
		function testRealDatasetResolves4DFixed(testCase)
			assumeTrue(testCase, isfile(testCase.realMetadata), ...
				'real morphobes dataset not present; skipping');
			meta = testCase.readMetadata(fileparts(testCase.realMetadata));
			in = testCase.makeInput(4);
			in.randomiseDistractors = false;
			in.distractorOne = 2;
			in.distractorTwo = 1;
			testCase.verifyConfigResolves(in, meta, fileparts(testCase.realMetadata));
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
		%> @brief Build a minimal task input struct for a config/test run.
		%> Uses the same defaults as clutil.checkInput for the IED task.
		% ===================================================================
		function in = makeInput(testCase, numTargets)
			in = struct();
			in.numTargets = numTargets;
			in.idDimension = 'colour';
			in.edDimension = 'shape';
			in.distractors = numTargets == 4;
			in.randomiseDistractors = true;
			in.distractorOne = 0;
			in.distractorTwo = 0;
			in.useExemplars = numTargets == 4;
		end

		% ===================================================================
		%> @brief Build a synthetic morphobes dataset using the REAL level
		%> encodings (procedural_microorganisms catalogue), so config tests
		%> are faithful to the shipped dataset.
		% ===================================================================
		function fixture = buildFixture(testCase)
			fixture = tempname;
			mkdir(fixture);
			pngDir = fullfile(fixture, 'png');
			mkdir(pngDir);
			% one shared tiny PNG; all metadata rows point at it
			pngPath = fullfile(pngDir, 'microbe_00001.png');
			imwrite(randi(255, 8, 8, 3, 'uint8'), pngPath);

			% real catalogue levels (non-contiguous):
			%   shape 0,1,2,4,7,8,11 | colour 0,1,2,3,6,7
			%   appendage 0,1,2,4,5 | texture 0,1,2,3,4 | exemplar 0-3
			% Full factorial (7*6*5*5*4 = 4200 rows) — the same structure
			% as the real dataset, so every config sample resolves.
			shapes = [0 1 2 4 7 8 11];
			colours = [0 1 2 3 6 7];
			app = [0 1 2 4 5];
			tex = [0 1 2 3 4];
			ex = 0:3;
			n = numel(shapes) * numel(colours) * numel(app) * numel(tex) * numel(ex);
			shapeLv = zeros(n, 1); colourLv = zeros(n, 1);
			appLv = zeros(n, 1); texLv = zeros(n, 1); exLv = zeros(n, 1);
			pngs = strings(n, 1);
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
				'VariableNames', {'shape_level', 'colour_level', ...
				'appendage_level', 'texture_level', 'exemplar', 'png_path'});
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
		%> @brief Verify every morphobe sample the config can present
		%> resolves to exactly one metadata row whose PNG exists: every
		%> relLevel x non-relevant value (pool or fixed) x exemplar combo.
		% ===================================================================
		function verifyConfigResolves(testCase, in, meta, folder)
			config = clutil.iedMorphobesConfig(in, meta);
			for s = 1:numel(config.sets)
				setCfg = config.sets(s);
				exemplars = setCfg.exemplarPool;
				if isempty(exemplars)
					exemplars = setCfg.exemplar;
				end
				% possible values for each non-relevant dimension
				nonRelVals = cell(1, numel(setCfg.nonRelevantDims));
				for k = 1:numel(setCfg.nonRelevantDims)
					if config.distractors && config.randomiseDistractors
						nonRelVals{k} = setCfg.distractorPools{k};
					else
						nonRelVals{k} = unique(setCfg.distractorValues{k});
					end
				end
				% cross product over non-relevant dims
				grids = cell(1, numel(nonRelVals));
				if isempty(nonRelVals)
					grids = {0};
				else
					[grids{:}] = ndgrid(nonRelVals{:});
				end
				for lv = setCfg.relLevels
					for i = 1:numel(grids{1})
						vals = struct('shape', 0, 'colour', 0, 'appendage', 0, 'texture', 0);
						for k = 1:numel(setCfg.nonRelevantDims)
							vals.(setCfg.nonRelevantDims{k}) = grids{k}(i);
						end
						for ex = exemplars
							testCase.verifyResolves(meta, folder, ...
								vals.shape, vals.colour, vals.appendage, vals.texture, ex, ...
								sprintf('set %d relDim=%s level=%d', s, setCfg.relDim, lv));
						end
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
			in.distractors = numTargets == 4;
			in.randomiseDistractors = true;
			in.distractorOne = 0;
			in.distractorTwo = 0;
			in.useExemplars = numTargets == 4;
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
