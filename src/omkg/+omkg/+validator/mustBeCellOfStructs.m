function mustBeCellOfStructs(cellArray)
    arguments
        cellArray (1,:) cell
    end

    if isempty(cellArray), return; end

    isCellOfStruct = cellfun(@isstruct, cellArray);
    assert(all(isCellOfStruct), ...
        "OMKG:Validator:MustBeCellOfStruct", ...
        'Expected input to be a cell array of structures.')
end
