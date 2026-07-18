% ========================================================================
%> @class TheConductorTest
%> @brief Class-based tests for theConductor methods that are dependency-free.
%>
%> The constructor is intentionally not used: it configures PTB and creates
%> a live ØMQ connection. An empty object is sufficient for methods whose
%> implementation does not access instance state.
% ========================================================================
classdef TheConductorTest < matlab.unittest.TestCase

	methods (TestClassSetup)
		function setupPath(~)
			addOptickaToPath;
		end
	end

	methods (Test, TestTags = {'CI'})
		% ===================================================================
		%> @brief Check the public HTTP constants used by the conductor.
		% ===================================================================
		function testHTTPConstants(testCase)
			verifyEqual(testCase, string(theConductor.baseURI), ...
				"http://localhost:9012");
			verifyEqual(testCase, theConductor.basePath, ...
				["api" "cmds" "proxies"]);
		end

		% ===================================================================
		%> @brief Map successful HTTP responses to protocol result strings.
		% ===================================================================
		function testHandleResponseSuccessCodes(testCase)
			conductor = theConductor.empty;
			ok = matlab.net.http.ResponseMessage(...
				matlab.net.http.StatusCode.OK);
			created = matlab.net.http.ResponseMessage(...
				matlab.net.http.StatusCode.Created);

			verifyEqual(testCase, conductor.handleResponse(ok), "ok");
			verifyEqual(testCase, conductor.handleResponse(created), "created");
		end

		% ===================================================================
		%> @brief Map conflict and missing-endpoint responses.
		% ===================================================================
		function testHandleResponseFailureCodes(testCase)
			conductor = theConductor.empty;
			conflict = matlab.net.http.ResponseMessage(...
				matlab.net.http.StatusCode.Conflict);
			notFound = matlab.net.http.ResponseMessage(...
				matlab.net.http.StatusCode.NotFound);

			verifyWarning(testCase, @() conductor.handleResponse(conflict), ...
				'theConductor:endpointExists');
			verifyWarning(testCase, @() conductor.handleResponse(notFound), ...
				'theConductor:invalidEndpoint');
			verifyEqual(testCase, conductor.handleResponse(conflict), "conflict");
			verifyEqual(testCase, conductor.handleResponse(notFound), "notfound");
		end

		% ===================================================================
		%> @brief Return an empty result when no HTTP response exists.
		% ===================================================================
		function testHandleResponseEmpty(testCase)
			conductor = theConductor.empty;
			result = conductor.handleResponse([]);

			verifyEqual(testCase, result, "");
		end

		% ===================================================================
		%> @brief Convert a transport failure into an empty response.
		% ===================================================================
		function testSendRequestFailure(testCase)
			conductor = theConductor.empty;
			request = matlab.net.http.RequestMessage(...
				matlab.net.http.RequestMethod.GET);
			uri = matlab.net.URI('http://127.0.0.1:1');

			response = conductor.sendRequest(request, uri);

			verifyEmpty(testCase, response);
		end
	end
end
