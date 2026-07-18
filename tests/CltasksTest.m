% ========================================================================
%> @class CltasksTest
%> @brief Class-based contract tests for CageLab task entry points.
%>
%> Full task execution requires PTB, a touch device, stimulus resources, and
%> reward/audio managers. These tests therefore exercise the common preflight
%> contract and protect the task-specific response rules without starting a
%> behavioral task.
% ========================================================================
classdef CltasksTest < matlab.unittest.TestCase

	properties (TestParameter)
		%> Tasks whose first operation is clutil.checkInput.
		validatedTask = {'startDragCategorisation', 'startMatchToSample', ...
			'startThings', 'startTouchTraining', 'startVisualOddball'}
	end

	methods (TestClassSetup)
		function setupPath(~)
			addOptickaToPath;
		end
	end

	methods (Test, TestTags = {'CI'})
		% ===================================================================
		%> @brief Ensure every task entry point exists and takes one input.
		% ===================================================================
		function testTaskEntryPointSignature(testCase, validatedTask)
			name = "cltasks." + validatedTask;
			functionHandle = str2func(name);
			expectedPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
				'+cltasks', char(validatedTask + ".m"));

			verifyEqual(testCase, nargin(functionHandle), 1);
			verifyEqual(testCase, which(name), expectedPath);
		end

		% ===================================================================
		%> @brief Reject invalid input before hardware initialization.
		% ===================================================================
		function testTaskRejectsNonStructInput(testCase, validatedTask)
			functionHandle = str2func("cltasks." + validatedTask);

			verifyError(testCase, @() functionHandle(1), ...
				'checkInput:InvalidInput');
		end

		% ===================================================================
		%> @brief Verify IED performs its task-type normalization first.
		% ===================================================================
		function testIEDRejectsNonTextTaskType(testCase)
			verifyError(testCase, @() cltasks.startIED(1), ...
				'MATLAB:structRefFromNonStruct');
		end

		% ===================================================================
		%> @brief Keep all eight IED stages represented in the task source.
		% ===================================================================
		function testIEDIncludesAllStages(testCase)
			source = fileread(which('cltasks.startIED'));
			stages = {'sd', 'sr', 'cd', 'cr', 'ids', 'idr', 'eds', 'edr'};

			for stage = stages
				verifyTrue(testCase, contains(source, ['''' stage{1} '''']), ...
					['missing IED stage: ' stage{1}]);
			end
		end

		% ===================================================================
		%> @brief Protect oddball hit, miss, and false-alarm decision branches.
		% ===================================================================
		function testVisualOddballResponseRules(testCase)
			source = fileread(which('cltasks.startVisualOddball'));

			verifyTrue(testCase, contains(source, 'isDeviant'));
			verifyTrue(testCase, contains(source, 'false alarm'));
			verifyTrue(testCase, contains(source, 'correct reject'));
			verifyTrue(testCase, contains(source, 'r.result = 1'));
			verifyTrue(testCase, contains(source, 'r.result = 0'));
		end

		% ===================================================================
		%> @brief Protect the MTS helper functions used for unique prefixes.
		% ===================================================================
		function testMatchToSampleUsesUniquePrefixHelpers(testCase)
			source = fileread(which('cltasks.startMatchToSample'));

			verifyTrue(testCase, contains(source, 'function [p, leftover] = pickAndRemove'));
			verifyTrue(testCase, contains(source, 'function [p1 p2 p3 p4 p5] = getPrefixes'));
			verifyTrue(testCase, contains(source, 'setxor(in,p)'));
		end
	end
end
