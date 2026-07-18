classdef RecordingBroadcast < handle
	%> Minimal broadcast double used to inspect telemetry without HTTP.

	properties
		lastMessage = struct.empty
	end

	methods
		function send(obj, message)
			obj.lastMessage = message;
		end
	end
end
