classdef TouchProcessDouble < handle
	%> Minimal touch-manager double for processTouch tests.

	properties
		eventAvail = true
		eventRelease = false
		eventPressed = true
		x = 3
		y = 4
		name = 'test-touch'
		window = struct('X', [], 'Y', [], 'radius', [])
		event = struct('Type', 2)
		firstWindowResult = true
		nextWindowResult = false
	end

	methods
		function [result, win, wasEvent] = checkTouchWindows(obj, ~, getEvent)
			if getEvent
				result = obj.firstWindowResult;
			else
				result = obj.nextWindowResult;
			end
			win = [];
			wasEvent = true;
		end

		function event = getEvent(obj)
			event = obj.event;
		end
	end
end
