function omNode = concatTypesIfHomogeneous(omNode)
% concatTypesIfHomogeneous - Create instance array (not cell) if all nodes are same type.
    allTypes = cellfun(@class, omNode, 'UniformOutput', false);
    if isscalar( unique(allTypes) )
        omNode = [omNode{:}];
    end
end
