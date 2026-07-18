% ========================================================================
%> @class ClutilTest
%> @brief Class-based tests for the deterministic CageLab utility code.
%>
%> These tests deliberately avoid opening PTB windows or contacting remote
%> services. Hardware-facing utilities are exercised only through branches
%> that do not require a live device.
% ========================================================================
classdef ClutilTest < matlab.unittest.TestCase

	properties
		%> Isolated fixture tree used by getThingsImages.
		fixtureDir char
	end

	methods (TestClassSetup)
		function setupPath(~)
			addOptickaToPath;
		end
	end

	methods (TestMethodSetup)
		function createFixture(testCase)
			testCase.fixtureDir = tempname;
			mkdir(testCase.fixtureDir);
		end
	end

	methods (TestMethodTeardown)
		function removeFixture(testCase)
			if ~isempty(testCase.fixtureDir) && exist(testCase.fixtureDir, 'dir')
				rmdir(testCase.fixtureDir, 's');
			end
		end
	end

	methods (Test, TestTags = {'CI'})
		% ===================================================================
		%> @brief Check the software version exported by clutil.
		% ===================================================================
		function testVersion(testCase)
			verifyEqual(testCase, clutil.version, '1.0.69');
		end

		% ===================================================================
		%> @brief Check that checkInput fills all required defaults.
		% ===================================================================
		function testCheckInputDefaults(testCase)
			in = clutil.checkInput();

			verifyEqual(testCase, in.density, 70);
			verifyEqual(testCase, in.distance, 30);
			verifyEqual(testCase, in.port, 9012);
			verifyTrue(testCase, in.debug);
			verifyTrue(testCase, in.dummy);
			verifyEqual(testCase, in.task, 'generic');
			verifyEqual(testCase, in.session.subjectName, 'TestSubject');
			repoRoot = fileparts(fileparts(which('clutil.checkInput')));
			verifyEqual(testCase, in.folder, ...
				fullfile(repoRoot, 'resources'));
		end

		% ===================================================================
		%> @brief Check that explicit false and zero values are preserved.
		% ===================================================================
		function testCheckInputPreservesExplicitValues(testCase)
			in = clutil.checkInput(struct('debug', false, 'port', 0, ...
				'task', 'custom', 'folder', testCase.fixtureDir));

			verifyFalse(testCase, in.debug);
			verifyEqual(testCase, in.port, 0);
			verifyEqual(testCase, in.task, 'custom');
			verifyEqual(testCase, in.folder, testCase.fixtureDir);
		end

		% ===================================================================
		%> @brief Reject non-struct input before task setup can begin.
		% ===================================================================
		function testCheckInputRejectsNonStruct(testCase)
			verifyError(testCase, @() clutil.checkInput(1), ...
				'checkInput:InvalidInput');
		end

		% ===================================================================
		%> @brief Reset trial-local state while advancing the loop number.
		% ===================================================================
		function testInitTrialVariables(testCase)
			r = struct('loopN', 4, 'keepRunning', false, 'result', 1, ...
				'value', 2, 'summary', 'old', 'unrelated', 42);

			r = clutil.initTrialVariables(r);

			verifyTrue(testCase, r.keepRunning);
			verifyEqual(testCase, r.loopN, 5);
			verifyEqual(testCase, r.result, -1);
			verifyTrue(testCase, isnan(r.value));
			verifyFalse(testCase, r.anyTouch);
			verifyTrue(testCase, isnan(r.reactionTime));
			verifyEmpty(testCase, r.summary);
			verifyEqual(testCase, r.unrelated, 42);
		end

		% ===================================================================
		%> @brief Return true and leave input unchanged when no ZMQ exists.
		% ===================================================================
		function testCheckMessagesWithoutConnection(testCase)
			in = struct('keepRunning', false, 'task', 'test');
			[out, keepRunning] = clutil.checkMessages(in);

			verifyTrue(testCase, keepRunning);
			verifyEqual(testCase, out, in);
		end

		% ===================================================================
		%> @brief Build every three-category image combination.
		% ===================================================================
		function testGetThingsImagesBuildsCombinations(testCase)
			testCase.makeCategory('A', {'a1.png', 'a2.JPG'});
			testCase.makeCategory('B', {'b1.png', 'b2.png', 'b3.txt'});
			testCase.makeCategory('C', {'c1.jpeg'});
			f = fullfile(testCase.fixtureDir, 'things');

			[object, files] = clutil.getThingsImages(...
				struct('folder', testCase.fixtureDir, 'folderThings', f));

			verifyEqual(testCase, object.A.N, 2);
			verifyEqual(testCase, object.B.N, 2);
			verifyEqual(testCase, object.C.N, 1);
			verifyEqual(testCase, numel(files), 5);
			verifyEqual(testCase, height(object.trials), 4);
			verifyEqual(testCase, width(object.trials), 3);
			verifyEqual(testCase, numel(unique(string(object.trials.A))), 2);
			verifyEqual(testCase, numel(unique(string(object.trials.B))), 2);
			verifyEqual(testCase, numel(unique(string(object.trials.C))), 1);
		end

		% ===================================================================
		%> @brief Equalize category sizes before generating combinations.
		% ===================================================================
		function testGetThingsImagesEqualizesCategories(testCase)
			testCase.makeCategory('A', {'a1.png', 'a2.png'});
			testCase.makeCategory('B', {'b1.png', 'b2.png', 'b3.png'});
			testCase.makeCategory('C', {'c1.png'});
			f = fullfile(testCase.fixtureDir, 'things');

			[object, ~] = clutil.getThingsImages(struct(...
				'folder', testCase.fixtureDir, 'folderThings', f, ...
				'equalizeImages', true));

			verifyEqual(testCase, object.A.N, 1);
			verifyEqual(testCase, object.B.N, 1);
			verifyEqual(testCase, object.C.N, 1);
			verifyEqual(testCase, height(object.trials), 1);
		end

		% ===================================================================
		%> @brief Reject a resource tree with fewer than three categories.
		% ===================================================================
		function testGetThingsImagesRequiresThreeCategories(testCase)
			testCase.makeCategory('A', {'a.png'});
			testCase.makeCategory('B', {'b.png'});
			f = fullfile(testCase.fixtureDir, 'things');

			verifyError(testCase, @() clutil.getThingsImages(...
				struct('folder', testCase.fixtureDir, 'folderThings', f)), '');
		end

		% ===================================================================
		%> @brief Construct the cogmoteGO status URI from custom settings.
		% ===================================================================
		function testStatusBaseURI(testCase)
			status = clutil.status('192.0.2.10', 8123);

			verifyEqual(testCase, string(status.baseURI), ...
				"http://192.0.2.10:8123");
			verifyEqual(testCase, status.ip, '192.0.2.10');
			verifyEqual(testCase, status.port, 8123);
		end

		% ===================================================================
		%> @brief Verify telemetry is packaged before it is broadcast.
		% ===================================================================
		function testBroadcastTrialPackagesTelemetry(testCase)
			dt = touchData('verbose', false);
			dt.data = struct('rewards', 2, 'random', 1);
			broadcast = RecordingBroadcast;
			in = struct('task', 'test', 'name', 'subject', ...
				'session', struct('sessionURL', 'session/123'));
			r = struct('ALFPath', fullfile('root', 'date', 'session'), ...
				'loopN', 7, 'trialN', 3, 'correctRateRecent', 0.8, ...
				'correctRate', 0.75, 'result', 1, 'reactionTime', 0.4, ...
				'phase', 2, 'hostname', 'host', 'version', '1.0', ...
				'comments', "test comment", 'broadcast', broadcast);

			clutil.broadcastTrial(in, r, dt, true);
			message = broadcast.lastMessage;

			verifyEqual(testCase, message.task, 'test');
			verifyEqual(testCase, message.loop_id, 7);
			verifyEqual(testCase, message.trial_id, 3);
			verifyEqual(testCase, message.rewards, 2);
			verifyEqual(testCase, message.random_rewards, 1);
			verifyTrue(testCase, message.is_running);
			verifyEqual(testCase, message.session_id, ...
				string(fullfile('root', 'date', 'session')));
		end

		% ===================================================================
		%> @brief Exercise the initial touch branch of processTouch.
		% ===================================================================
		function testProcessTouchStartsDrag(testCase)
			tM = TouchProcessDouble;
			object = TouchObjectDouble(10, 20);
			in = struct('debug', false);

			[success, inTouch, nowX, nowY, tx, ty, object] = ...
				clutil.processTouch(tM, in, object, [], [], [], false, [], ...
					[], [], []);

			verifyFalse(testCase, success);
			verifyTrue(testCase, inTouch);
			verifyEqual(testCase, [nowX nowY], [3 4]);
			verifyEqual(testCase, tx, 3);
			verifyEqual(testCase, ty, 4);
			verifyEqual(testCase, object.lastXY, [3 4]);
			verifyEqual(testCase, object.alphaOut, 0.9);
		end

		% ===================================================================
		%> @brief Exercise movement and target-window success in processTouch.
		% ===================================================================
		function testProcessTouchReachesTarget(testCase)
			tM = TouchProcessDouble;
			tM.firstWindowResult = true;
			tM.nextWindowResult = true;
			tM.eventRelease = false;
			tM.eventPressed = true;
			object = TouchObjectDouble(10, 20);
			target = TouchObjectDouble(30, 40);
			in = struct('debug', false);

			[success, inTouch, ~, ~, tx, ty, ~] = ...
				clutil.processTouch(tM, in, object, target, [], [], true, ...
					[], [], [], []);

			verifyTrue(testCase, success);
			verifyTrue(testCase, inTouch);
			verifyEqual(testCase, tx, 3);
			verifyEqual(testCase, ty, 4);
		end

		% ===================================================================
		%> @brief Exercise release handling in processTouch.
		% ===================================================================
		function testProcessTouchHandlesRelease(testCase)
			tM = TouchProcessDouble;
			tM.eventRelease = true;
			tM.eventPressed = false;
			tM.event.Type = 4;
			object = TouchObjectDouble(10, 20);
			target = TouchObjectDouble(30, 40);
			in = struct('debug', false);

			[success, inTouch, ~, ~, tx, ty, ~] = ...
				clutil.processTouch(tM, in, object, target, [], [], true, ...
					1, 2, 3, 4);

			verifyFalse(testCase, success);
			verifyFalse(testCase, inTouch);
			verifyEmpty(testCase, tx);
			verifyEmpty(testCase, ty);
		end
	end

	methods (Access = private)
		function makeCategory(testCase, name, fileNames)
			category = fullfile(testCase.fixtureDir, 'things', name);
			mkdir(category);
			for ii = 1:numel(fileNames)
				fileID = fopen(fullfile(category, fileNames{ii}), 'w');
				fclose(fileID);
			end
		end
	end
end
