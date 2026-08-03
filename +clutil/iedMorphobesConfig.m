function config = iedMorphobesConfig(numTargets, metaTable)
	% IEDMORPHOBESCONFIG Return the stimulus level configuration for the
	% morphobes IED task.
	%   config = iedMorphobesConfig(numTargets)
	%
	% Returns a struct with:
	%   dimLevels   — struct with fields shape, colour, appendage, texture.
	%                 Each field is a 3xN matrix (rows = stimulus sets 1-3,
	%                 cols = targets) of morphobes dimension levels.
	%                 Set 1: SD, SR, CD, CR.  Set 2: IDS, IDR.  Set 3: EDS, EDR.
	%   setExemplars — 1x3 vector of exemplar levels per set.
	%
	% numTargets must be 2 (2D variant: shape + colour, two targets) or
	% 4 (4D variant: shape + colour + appendage + texture, four targets).
	% Level values are chosen to exist in the unified morphobes dataset
	% (shape 0-7, colour 0-7, appendage 0-3, texture 0-3, exemplar 0-3).
	% Extracted as a standalone function so tests can validate the level
	% configuration against the dataset metadata without running the task.

	arguments (Input)
		numTargets (1,1) double {mustBeMember(numTargets, [2 4])}
		metaTable
	end

	arguments (Output)
		config struct
	end

	% Each dimension: 3 sets of levels (rows = sets, cols = targets).
	% Dimensions with fewer levels reuse levels across sets, using
	% different exemplars to create novel-looking stimuli.
	config = struct();
	config.numTargets = numTargets;
	if numTargets == 4
		% 4D: four levels per set, four dimensions
		config.dimLevels.shape     = [0 1 2 3; 4 5 6 7; 0 1 2 3];   % 8 unique
		config.dimLevels.colour    = [0 1 2 3; 4 5 6 7; 0 1 2 3];   % 8 unique
		config.dimLevels.appendage = [0 1 2 3; 0 1 2 3; 0 1 2 3];   % 4 levels, all reuse
		config.dimLevels.texture   = [0 1 2 3; 0 1 2 3; 0 1 2 3];   % 4 levels, all reuse
		% Exemplar per set — all dimensions within a set use the same exemplar
		config.setExemplars = 0 : maxExemplar;
	else
		% 2D: two levels per set, shape and colour vary (appendage/texture constant).
		% Level values chosen for maximal visual distinctness within the
		% current unified dataset (shape levels 0-7, colour levels 0-7).
		config.dimLevels.shape     = [3 6; 1 5; 0 7];   % 6 unique
		config.dimLevels.colour    = [0 1; 2 4; 6 7];   % 6 unique
		config.dimLevels.appendage = [defAppendage defAppendage; defAppendage defAppendage; defAppendage defAppendage];   % constant
		config.dimLevels.texture   = [defTexture defTexture; defTexture defTexture; defTexture defTexture];   % constant
		% 2D dataset only has exemplar 0
		config.setExemplars = [0 0 0 0];
	end
end
