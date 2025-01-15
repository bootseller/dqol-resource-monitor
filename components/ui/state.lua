UiState = {}

---@alias UiStateMenuFilter {resources: table<string, true>, surface: integer?, onlyTracked: boolean, onlyEmpty: boolean, maxPercent: integer, maxEstimatedDepletion: integer?, minAmount: integer, search: string?, orderBy: nil|'resource'|'name'|'amount'|'percent'|'rate'|'depletion', orderByDesc: boolean?}
---@alias UiStateMenu {tab: integer?, open_site_id: integer?, open_surface_id: integer?, sites_filters: UiStateMenuFilter, dashboard_filters: UiStateMenuFilter, use_products: boolean}

---@alias UiStateDashboard {show_headers: boolean, prepend_surface_name: boolean}

---@alias UiStatePlayer {menu: UiStateMenu, dashboard: UiStateDashboard}
---@alias GlobalUi {players: table<integer, UiStatePlayer>?}

---@param player LuaPlayer
function UiState.bootPlayer(player)
    UiState.reset(player.index)
end

---Reset the entire UI State for a player (or all if none provided)
---@param player_index integer?
function UiState.reset(player_index)
    if storage.ui == nil or storage.ui.players == nil then
        storage.ui = {
            players = {},
        }
    end

    if player_index ~= nil then
        storage.ui.players[player_index] = UiState.generateFreshPlayerState()
    else
        for key, state in pairs(storage.ui.players) do
            storage.ui.players[key] = UiState.generateFreshPlayerState()
        end
    end
end

---Get the UI State for a single player. Will create a state if this player is not known.
---@param player_index integer
---@return UiStatePlayer
function UiState.get(player_index)
    if storage.ui == nil or storage.ui.players == nil then
        UiState.reset(player_index)
    end

    if storage.ui.players[player_index] == nil then
        UiState.reset(player_index)
    end

    return storage.ui.players[player_index]
end

---Generate a new player state
---@return UiStatePlayer
function UiState.generateFreshPlayerState()
    return {
        menu = {
            tab = nil,
            open_site_id = nil,
            open_surface_id = nil,
            use_products = table_size(Resources.cleanResources()) > table_size(Resources.cleanProducts()),
            sites_filters = {
                resources = {},
                surface = nil,
                onlyTracked = true,
                onlyEmpty = false,
                maxPercent = 100,
                maxEstimatedDepletion = nil,
                minAmount = 0,
                search = nil,
                orderBy = nil,
                orderByDesc = false,
            },
            dashboard_filters = {
                resources = {},
                surface = nil,
                onlyTracked = true,
                onlyEmpty = false,
                maxPercent = 100,
                maxEstimatedDepletion = 4 * 60 * 60 * 60, -- four hours
                minAmount = 0,
                search = nil,
                orderBy = 'percent',
                orderByDesc = false,
            }
        },
        dashboard = {
            show_headers = false,
            prepend_surface_name = false,
        },
    }
end

return UiState
