function result = getOrdinalNumberString(val)
    if val == 1
        result = sprintf('%dst', val); %1st
    elseif val == 2
        result = sprintf('%dnd', val); %2nd
    elseif val == 3
        result = sprintf('%drd', val); %3rd
    else
        result = sprintf('%dth', val); %nth
    end
end