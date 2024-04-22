local Table = require('__stdlib__/stdlib/utils/table')

Sites = {
    updater = {},
}

---@alias IntPosition {x: integer, y: integer}
---@alias DirectionIdentifier 'top'|'bottom'|'left'|'right'
---@alias SiteChunkKey string A special format key, encoding the chunk position
---@alias SiteChunkBorders {left: integer, right: integer, top: integer, bottom: integer}
---@alias SiteChunk {x: integer, y: integer, tiles: integer, amount: integer, updated: integer, borders: SiteChunkBorders}
---@alias SiteArea {left: integer, right: integer, top: integer, bottom: integer, x: integer, y: integer}
---@alias Site {id: integer, type: string, name: string, surface: integer, chunks: table<SiteChunkKey, SiteChunk>, amount: integer, initial_amount: integer, index: integer, since: integer, area: SiteArea, tracking: boolean, map_tag: LuaCustomChartTag?}

---@alias GlobalSitesUpdater {pointer: integer, queue: table<integer, table<1|2, integer|SiteChunkKey>>} -- queue sub-entries simply have 1: siteId and 2: chunkId
---@alias GlobalSites {surfaces: table<integer, table<string, Site[]?>?>?, ids: table<integer, Site>?, updater: GlobalSitesUpdater}
---@cast global {sites: GlobalSites?}

local names = {
    'Julia',
    'Midderfield',
    'Amara',
    'Kaleigh',
    'Zoe',
    'Josephine',
    'Tiara',
    'Gia',
    'Julianne',
    'Leila',
    'Amari',
    'Daisy',
    'Daniella',
    'Raquel',
    'Westray',
    'Carningsby',
    'Doveport',
    'Sanlow',
    'Hillford',
    'Aberystwyth',
    'Thorpeness',
    'Malrton',
    'Ely',
}

---@param pos IntPosition
---@return string
local function pos_to_compass_direction(pos)
    local direction
    if pos.y < 0 then direction = 'N' else direction = 'S' end
    if pos.x > 0 then direction = direction .. 'E' else direction = direction .. 'W' end
    return direction
end

---@param pos IntPosition?
---@return string
local function get_random_name(pos)
    local name = names[math.random(1, #names)]
    if pos ~= nil then
       name = pos_to_compass_direction(pos) .. ' ' .. name 
    end
    return name
end

---@param name string
---@return SignalID
local function get_signal_id(name)
    local type = Resources.types[name]
    return {
        type = type.type,
        name = type.name,
    }
end

---@param border integer
---@param xBase integer
---@param yBase integer
---@param surface integer
local function helper_highligh_chunk_border_lr(border, xBase, yBase, surface, color)
    local x = xBase
    for i = 0, 31, 1 do
        if bit32.band(border, bit32.lshift(1, i)) > 0 then
            local y = yBase + i
            rendering.draw_rectangle {
                color = color,
                filled = true,
                left_top = { x = x, y = y },
                right_bottom = { x = x + 1, y = y + 1 },
                surface = surface,
                time_to_live = 200,
                draw_on_ground = true,
            }
        end
    end
end

---@param border integer
---@param xBase integer
---@param yBase integer
---@param surface integer
local function helper_highligh_chunk_border_tb(border, xBase, yBase, surface, color)
    local y = yBase
    for i = 0, 31, 1 do
        if bit32.band(border, bit32.lshift(1, i)) > 0 then
            local x = xBase + i
            rendering.draw_rectangle {
                color = color,
                filled = true,
                left_top = { x = x, y = y },
                right_bottom = { x = x + 1, y = y + 1 },
                surface = surface,
                time_to_live = 200,
                draw_on_ground = true,
            }
        end
    end
end

---Highlight a given site in the game world
---@param site Site
function Sites.highlight_site(site)
    local color = {
        r = 0,
        g = math.random(0, 255),
        b = math.random(128, 255),
    }

    rendering.draw_rectangle {
        color = color,
        left_top = { x = site.area.left, y = site.area.top },
        right_bottom = { x = site.area.right + 1, y = site.area.bottom + 1},
        surface = site.surface,
        time_to_live = 200,
    }

    rendering.draw_circle {
        color = {r = 255, g = 0, b = 0},
        radius = 1,
        target = { x = site.area.x + 0.5, y = site.area.y + 0.5 },
        surface = site.surface,
        time_to_live = 200,
    }

    for key, chunk in pairs(site.chunks) do
        if chunk.borders.left > 0 then
            helper_highligh_chunk_border_lr(chunk.borders.left, chunk.x * 32, chunk.y * 32, site.surface, { r = 255, g = 128, b = 0 })
        end

        if chunk.borders.right > 0 then
            helper_highligh_chunk_border_lr(chunk.borders.right, ((chunk.x + 1) * 32) - 1, chunk.y * 32, site.surface, { r = 255, g = 0, b = 128 })
        end

        if chunk.borders.top > 0 then
            helper_highligh_chunk_border_tb(chunk.borders.top, chunk.x * 32, chunk.y * 32, site.surface, { r = 255, g = 64, b = 0 })
        end

        if chunk.borders.bottom > 0 then
            helper_highligh_chunk_border_tb(chunk.borders.bottom, chunk.x * 32, ((chunk.y + 1) * 32) - 1, site.surface, { r = 255, g = 0, b = 64 })
        end
    end
end

---Calculate outer chunks
---@param site Site
---@return SiteChunkKey[]
local function get_outer_chunks(site)
    local outer_chunks = {}
    for key, chunk in pairs(site.chunks) do
        if chunk.borders.bottom > 0 or chunk.borders.top > 0 or chunk.borders.left > 0 or chunk.borders.right > 0 then
            table.insert(outer_chunks, key)
        end
    end
    return outer_chunks
end

---Calculate the keys to the chunks that are neighboring this chun
---@param chunk SiteChunk
---@return table<SiteChunkKey, {direction: DirectionIdentifier, opposite: DirectionIdentifier, diagonal: nil|'left'|'right'}>
local function get_neighboring_chunk_keys(chunk)
    local neighbors = {}
    -- directly neighboring
    if chunk.borders.top > 0 then
        neighbors[chunk.x .. ',' .. chunk.y - 1] = { direction = 'top', opposite = 'bottom' }
    end
    if chunk.borders.bottom > 0 then
        neighbors[chunk.x .. ',' .. chunk.y + 1] = { direction = 'bottom', opposite = 'top' }
    end
    if chunk.borders.left > 0 then
        neighbors[chunk.x - 1 .. ',' .. chunk.y] = { direction = 'left', opposite = 'right' }
    end
    if chunk.borders.right > 0 then
        neighbors[chunk.x + 1 .. ',' .. chunk.y] = { direction = 'right', opposite = 'left' }
    end

    -- diagonal corners
    if bit32.band(chunk.borders.top, 1) then
        neighbors[chunk.x - 1 .. ',' .. chunk.y - 1] = { direction = 'top', opposite = 'bottom', diagonal = 'left' }
    end
    if bit32.band(chunk.borders.top, 2147483648) then
        neighbors[chunk.x + 1 .. ',' .. chunk.y - 1] = { direction = 'top', opposite = 'bottom', diagonal = 'right' }
    end
    if bit32.band(chunk.borders.bottom, 1) then
        neighbors[chunk.x - 1 .. ',' .. chunk.y - 1] = { direction = 'bottom', opposite = 'top', diagonal = 'left' }
    end
    if bit32.band(chunk.borders.bottom, 2147483648) then
        neighbors[chunk.x + 1 .. ',' .. chunk.y - 1] = { direction = 'bottom', opposite = 'top', diagonal = 'right' }
    end
    return neighbors
end

---@param area SiteArea
---@return SiteArea
local function update_site_area_center(area)
    area.x = area.left + math.floor((area.right - area.left) / 2)
    area.y = area.top + math.floor((area.bottom - area.top) / 2)
    return area
end

---@param areaBase SiteArea
---@param areaAdd SiteArea
---@return SiteArea
local function merge_site_areas(areaBase, areaAdd)
    if areaAdd.top < areaBase.top then areaBase.top = areaAdd.top end
    if areaAdd.bottom > areaBase.bottom then areaBase.bottom = areaAdd.bottom end
    if areaAdd.left < areaBase.left then areaBase.left = areaAdd.left end
    if areaAdd.right > areaBase.right then areaBase.right = areaAdd.right end
    return update_site_area_center(areaBase)
end

---Merge a site into another one. Returns the first param with the second merged into it
---@param siteBase Site
---@param siteAdd Site
---@return Site
local function merge_sites(siteBase, siteAdd)
    siteBase.amount = siteBase.amount + siteAdd.amount
    siteBase.initial_amount = siteBase.initial_amount + siteAdd.initial_amount
    siteBase.chunks = Table.dictionary_combine(siteBase.chunks, siteAdd.chunks)
    siteBase.since = math.min(siteBase.since, siteAdd.since)
    siteBase.area = merge_site_areas(siteBase.area, siteAdd.area)
    return siteBase
end

---@param resources LuaEntity[]
---@param surface LuaSurface
---@param chunk ChunkPositionAndArea
---@return Site[]
function Sites.create_from_chunk_resources(resources, surface, chunk)
    ---@type Site[]
    local types = {}
    local chunk_key = chunk.x .. ',' .. chunk.y

    for key, resource in pairs(resources) do
        local pos = {
            x = math.floor(resource.position.x),
            y = math.floor(resource.position.y),
        }

        if not types[resource.name] then
            types[resource.name] = {
                id = 0,
                type = resource.name,
                name = get_random_name(pos),
                surface = surface.index,
                chunks = {},
                amount = 0,
                initial_amount = 0,
                since = game.tick,
                index = 0,
                area = { top = pos.y, bottom = pos.y, left = pos.x, right = pos.x },
                tracking = settings.global['dqol-resource-monitor-site-track-new'].value,
            }

            types[resource.name].chunks[chunk_key] = {
                x = chunk.x,
                y = chunk.y,
                tiles = 0,
                amount = 0,
                updated = game.tick,
                borders = {
                    top = 0,
                    bottom = 0,
                    left = 0,
                    right = 0,
                },
            }
        end

        local site = types[resource.name]
        local chunk = site.chunks[chunk_key]

        -- update chunk
        chunk.amount = chunk.amount + resource.amount
        chunk.tiles = chunk.tiles + 1

        -- update site
        site.amount = site.amount + resource.amount
        site.initial_amount = site.initial_amount + (resource.initial_amount or resource.amount)

        -- check for borders
        local modX = pos.x % 32
        local modY = pos.y % 32

        if modX == 0 then
            chunk.borders.left = bit32.bor(chunk.borders.left, bit32.lshift(1, modY))
        elseif modX == 31 then
            chunk.borders.right = bit32.bor(chunk.borders.right, bit32.lshift(1, modY))
        end

        if modY == 0 then
            chunk.borders.top = bit32.bor(chunk.borders.top, bit32.lshift(1, modX))
        elseif modY == 31 then
            chunk.borders.bottom = bit32.bor(chunk.borders.bottom, bit32.lshift(1, modX))
        end

        -- expand area
        if pos.x > site.area.right then
            site.area.right = pos.x
        elseif pos.x < site.area.left then
            site.area.left = pos.x
        end
        if pos.y > site.area.bottom then
            site.area.bottom = pos.y
        elseif pos.y < site.area.top then
            site.area.top = pos.y
        end
    end

    for _, site in pairs(types) do
        update_site_area_center(site.area)
    end

    return types
end

function Sites.reset_cache()
    global.sites = {
        surfaces = {},
        ids = {},
        updater = {
            queue = {},
            pointer = 1,
        },
    }
end

---Add a new site to the cache
---@param site Site
function Sites.add_site_to_cache(site)
    if not global.sites.surfaces[site.surface] then global.sites.surfaces[site.surface] = {} end
    if not global.sites.surfaces[site.surface][site.type] then global.sites.surfaces[site.surface][site.type] = {} end

    local outer_chunks = get_outer_chunks(site)

    -- now check if this borders any other sites
    local matches = {}
    for _, chunkKey in pairs(outer_chunks) do
        local chunk = site.chunks[chunkKey]
        -- calculate the relevant neighbors first
        local neighborKeys = get_neighboring_chunk_keys(chunk)

        for neighborKey, d in pairs(neighborKeys) do
            local direction = d.direction
            local otherDirection = d.opposite
            local diagonal = d.diagonal
            for siteKey, otherSite in pairs(global.sites.surfaces[site.surface][site.type]) do
                local otherChunk = otherSite.chunks[neighborKey]
                if otherChunk ~= nil then
                    -- now check if they actually match up
                    if diagonal == nil then
                        if bit32.band(chunk.borders[direction], otherChunk.borders[otherDirection]) > 0 then
                            matches[otherSite.id] = otherSite
                            break
                        end
                    elseif diagonal == 'left' then
                        if bit32.band(otherChunk.borders[otherDirection], 2147483648) then
                            matches[otherSite.id] = otherSite
                            break
                        end
                    else -- diagonal == right
                        if bit32.band(otherChunk.borders[otherDirection], 1) then
                            matches[otherSite.id] = otherSite
                            break
                        end
                    end
                end
            end
        end
    end

    -- check for the matches array
    if table_size(matches) > 0 then
        for _, otherSite in pairs(matches) do
            -- merge into here
            otherSite = merge_sites(otherSite, site)

            if _DEBUG then
                game.print('Merge into site #' .. otherSite.id .. ' ' .. otherSite.name)
            end

            if site.id > 0 then
                -- the old site existed before
                -- now that they are merged the old one can be removed
                Sites.remove_site_from_cache(site)

                if _DEBUG then
                    game.print('Removed #' .. site.id .. ' after merge')
                end
            end

            -- swap site for next match
            site = otherSite
        end
    else
        -- we did find any matches, so we simply add it now
        local index = #global.sites.surfaces[site.surface][site.type] + 1
        site.index = index
        global.sites.surfaces[site.surface][site.type][index] = site
    
        -- add to ids
        local nextId = #(global.sites.ids) + 1
        site.id = nextId
        global.sites.ids[nextId] = site
    
        if _DEBUG then
            game.print('Added new site #' .. site.id .. ' ' .. site.name)
        end
    end
end

---@param sites Site[]
function Sites.add_sites_to_cache(sites)
    for key, site in pairs(sites) do
        Sites.add_site_to_cache(site)
    end
end

function Sites.update_site_map_tag(site)
    if settings.global['dqol-resource-monitor-site-map-markers'].value == true then
        local text = site.name .. ' ' .. Util.Integer.toExponentString(site.amount)
        if site.map_tag == nil then
            site.map_tag = game.forces[Scanner.DEFAULT_FORCE].add_chart_tag(site.surface, {
                position = site.area,
                text = text,
                icon = get_signal_id(site.type),
            })
        else
            site.map_tag.text = text
        end
    else
        -- remove if the tag exists
        if site.map_tag ~= nil then
            site.map_tag.destroy()
            site.map_tag = nil
        end
    end
end

---@param site Site
---@return integer
function Sites.get_site_tiles(site)
    local tiles = 0
    for _, chunk in pairs(site.chunks) do
        tiles = chunk.tiles + tiles
    end
    return tiles
end

---@param site Site
---@return integer
function Sites.get_site_updated(site)
    local min = nil
    for _, chunk in pairs(site.chunks) do
        if min == nil or chunk.updated < min then min = chunk.updated end
    end
    return min
end

---@param surface_index integer
---@return table<string, Site[]?>
function Sites.get_sites_from_cache(surface_index)
    return global.sites.surfaces[surface_index] or {}
end

---@return table<integer, table<string, Site[]?>>
function Sites.get_sites_from_cache_all()
    return global.sites.surfaces
end

---@param surface_index integer
---@param type string
---@param index integer
---@return Site?
function Sites.get_site_from_cache(surface_index, type, index)
    if global.sites.surfaces[surface_index] == nil then return nil end
    if global.sites.surfaces[surface_index][type] == nil then return nil end
    return global.sites.surfaces[surface_index][type][index] or nil
end

---Get site from cache using ID
---@param id integer
---@return Site?
function Sites.get_site_by_id(id)
    return global.sites.ids[id] or nil;
end

---Get site from cache, just by ID
---@param id integer
---@return table<integer, Site>
function Sites.get_sites_by_id()
    return global.sites.ids
end

---@param siteId integer
---@param chunkKey SiteChunkKey
function Sites.update_site_chunk(siteId, chunkKey)
    local site = Sites.get_site_by_id(siteId)
    if site == nil then return nil end
    local chunk = site.chunks[chunkKey]
    if chunk == nil then return nil end

    local surface = game.surfaces[site.surface]
        local x = chunk.x * 32
        local y = chunk.y * 32
        local area = { left_top = { x = x, y = y }, right_bottom = { x = x + 32, y = y + 32 } }
        local resources = surface.find_entities_filtered {
            area = area,
            name = site.type,
        }

    local sum = 0
        for __, resource in pairs(resources) do
        sum = sum + resource.amount
        end
    -- incrementally update site amount
    site.amount = site.amount - (chunk.amount - sum)

    -- remove if empty
    if #resources == 0 then
        site.chunks[chunkKey] = nil
        return nil
    end

    chunk.amount = sum
    chunk.tiles = #resources
    chunk.updated = game.tick
end

---@param site Site
function Sites.update_cached_site(site)
    for chunkKey, chunk in pairs(site.chunks) do
        Sites.update_site_chunk(site.id, chunkKey)
    end

    Sites.update_site_map_tag(site)
end

---@param site Site
function Sites.remove_site_from_cache(site)
    if site.map_tag ~= nil then site.map_tag.destroy() end
    global.sites.ids[site.id] = nil
    global.sites.surfaces[site.surface][site.type][site.index] = nil
end

function Sites.updater.onIncremental()
    -- local profiler = game.create_profiler(false)
    local set = global.sites.updater.queue[global.sites.updater.pointer]
    if set == nil then
        -- we need to generate a new queue now
        Sites.updater.createQueue()

        profiler.stop()
        -- game.print(profiler)
        -- game.print('Created queue')
        return
    end

    for _, tuple in pairs(set) do
        Sites.update_site_chunk(tuple[1], tuple[2])
    end

    global.sites.updater.pointer = global.sites.updater.pointer + 1

    -- profiler.stop()
    -- game.print(profiler)
    -- game.print('Update ' .. global.sites.updater.pointer .. ' of ' .. #(global.sites.updater.queue) .. ' (' .. #set .. ' chunks)')
end

function Sites.updater.onAll()
    -- local profiler = game.create_profiler(false)
    for siteId, site in pairs(Sites.get_sites_by_id()) do
        if site.tracking then
            Sites.update_cached_site(site)
        end
    end
    -- profiler.stop()
    -- game.print(profiler)
end

function Sites.updater.createQueue()
    local queue = {{}}
    local currentSet = 1
    local setSize = settings.global['dqol-resource-monitor-site-chunks-per-update'].value
    for siteId, site in pairs(Sites.get_sites_by_id()) do
        if site.tracking then
            for chunkId, chunk in pairs(site.chunks) do
                if #(queue[currentSet]) >= setSize then
                    -- start a new set
                    currentSet = currentSet + 1
                    queue[currentSet] = {}
                end
                -- insert into the current set
                table.insert(queue[currentSet], { siteId, chunkId })
            end
        end
    end
    global.sites.updater = {
        queue = queue,
        pointer = 1,
    }
end

function Sites.boot()
    local func = Sites.updater.onIncremental
    if settings.global['dqol-resource-monitor-site-chunks-per-update'].value == 0 then
        func = Sites.updater.onAll
    end
    script.on_nth_tick(settings.global['dqol-resource-monitor-site-ticks-between-updates'].value, func)
end

function Sites.onInitMod()
    Sites.reset_cache()
end
