function tf = isOpenMindsInstanceIRI(iris)
% isOpenMindsInstanceIRI - Whether each IRI names an openMINDS controlled instance
%
% Syntax:
%   tf = omkg.internal.conversion.isOpenMindsInstanceIRI(iris)
%
% Input Arguments:
%   iris - String array of IRIs.
%
% Output Arguments:
%   tf - Logical array, true where the IRI has the shape
%       <namespace>/instances/<typeName>/<instanceName>.
%
%   That is the only shape openminds.utility.parseInstanceIRI accepts, so
%   an IRI of any other shape throws once it reaches
%   openminds.instanceFromIRI. The check is restricted to the shape:
%   whether the type or instance exists is version dependent.
%
%   The Knowledge Graph does not escape "/" in instance names (for example
%   "molecularEntity/GABA-A/BZ"), so such an IRI can not be split into a
%   type and a name unambiguously and is rejected.

    arguments
        iris string
    end

    iris = reshape(iris, 1, []);
    if isempty(iris)
        tf = false(1, 0);
        return
    end

    tf = startsWith(iris, omkg.constants.OpenMINDSInstanceIRIPrefix);

    instancePath = repmat("", size(iris));
    instancePath(tf) = extractAfter(iris(tf), "/instances/");
    tf = tf ...
        & count(instancePath, "/") == 1 ...
        & ~startsWith(instancePath, "/") ...
        & ~endsWith(instancePath, "/");
end
