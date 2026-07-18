classdef TouchObjectDouble < handle
	%> Minimal stimulus double for processTouch tests.

	properties
		xFinalD
		yFinalD
		lastXY = []
		alphaOut = 1
	end

	methods
		function obj = TouchObjectDouble(x, y)
			obj.xFinalD = x;
			obj.yFinalD = y;
		end

		function updateXY(obj, x, y, ~)
			obj.lastXY = [x y];
		end
	end
end
