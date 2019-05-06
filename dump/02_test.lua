

local mapping = {

    frame = 'tracks',
}


function tablediff(t1, t2)
    local added = {}
    local removed = {}

    local k1 = table.keys(t1)
    local k2 = table.keys(t2)

    local i2 = 1
    local i1 = 1
    while i1 <= #k1 and i2 <= #k2 do
        if k1[i1] ~= k2[i2] then
            print('removed', k1[i1], t1[k1[i1]])
            table.insert(removed, {[k1[i1]] = t1[k1[i1]]})
            if k1[i1] < k2[i2] then
                i1 = i1 + 1
            else
                i2 = i2 + 1
            end
        elseif t1[i1] ~= t2[i2] then
            print('removed', k1[i1], t1[k1[i1]])
            table.insert(removed, {[k1[i1]] = t1[k1[i1]]})
            print('added', k2[i2], t2[k2[i2]])
            table.insert(added, {[k2[i2]] = t2[k2[i2]]})
            i1 = i1 + 1
            i2 = i2 + 2
        else
            i1 = i1 + 1
            i2 = i2 + 2
        end
    end
    while i2 < #k2 do
            table.insert(added, {[k2[i2]] = t2[k2[i2]]})
            i2 = i2 + 2
    end

    return removed, added
end

function tablepatch(t1, t2)
    local added = {}
    local removed = {}

    local k1 = table.keys(t1)
    local k2 = table.keys(t2)

    local i2 = 1
    local i1 = 1
    while i1 <= #k1 and i2 <= #k2 do
        if k1[i1] ~= k2[i2] then
            if k1[i1] < k2[i2] then
                i1 = i1 + 1
            else
                i2 = i2 + 1
            end
        elseif t1[i1] ~= t2[i2] then
            print('removed', k1[i1], t1[k1[i1]])
            table.insert(removed, {[k1[i1]] = t1[k1[i1]]})
            print('added', k2[i2], t2[k2[i2]])
            table.insert(added, {[k2[i2]] = t2[k2[i2]]})
            i1 = i1 + 1
            i2 = i2 + 2
        else
            i1 = i1 + 1
            i2 = i2 + 2
        end
    end
    while i2 < #k2 do
            table.insert(added, {[k2[i2]] = t2[k2[i2]]})
            i2 = i2 + 2
    end

    return removed, added
end

return nil

return {
  name = 'test',
  number = 0,
  install = function(x)
    xtouch = x
    clear_assigns()
    state = renoise.Document.create('mixer_state') {
      page_number = 1,
      track_offset = 0,
      post = true
    }
    init_mixer()
  end,
  uninstall = function(x)
  end
}
