local COMPAT = require("sunglasses.compat")
local logger = require("sunglasses.log")
local defaults = require("sunglasses.defaults")
local Highlight = require("sunglasses.highlight")
local Window = require("sunglasses.window")

local M = {
    highlights = {},
    __augroup_id = nil,
    __augroup_name = "Sunglasses",
    __hl_namespace = nil,
    __hl_namespace_name = 'sunglasses',
    __timer = nil,
    active_hls = nil,
    inactive_hls = nil,
    __last_hl_update = -1,
    version = 0.1
}

local function setup_hl_namespace()
    M.__hl_namespace = vim.api.nvim_create_namespace(M.__hl_namespace_name)
    logger.debug("Setting up namespace", M.__hl_namespace)
end

local function get_all_highlights(force)
    logger.info("Gathering all current highlights")
    local user_config = defaults.get_config()
    local highlights = vim.api.nvim_get_hl(0, {})
    local is_same = true
    for highlights_name, highlight in pairs(highlights) do
        local excluded = defaults.is_highlight_excluded(highlights_name)
        if excluded or (M.highlights[highlights_name] and not force) then
            goto continue
        end
        local new_highlight = Highlight:new({
            highlight = highlight,
            namespace = M.__hl_namespace,
            name = highlights_name,
            adjustment = user_config.filter_type,
            adjustment_level = user_config.filter_percent
        })
        M.highlights[highlights_name] = new_highlight
        ::continue::
    end
    local purged_hls = {}
    for hl, _ in pairs(M.highlights) do
        local found_match = false
        for current_highlight, _ in pairs(highlights) do
            if current_highlight == hl then
                found_match = true
                break
            end
        end
        if not found_match then
            table.insert(purged_hls, hl)
        end
    end
    if #purged_hls > 0 then
        logger.trace("Purging", #purged_hls, "unused highlights")
        for _, hl in ipairs(purged_hls) do
            M.highlights[hl] = nil
        end
    end
    -- Nothing changed so return
    if is_same then return end
    M.__last_hl_update = COMPAT.luv.hrtime()
    if M.__hl_namespace == 0 then
        -- Since we are using the global namesapce, set these things there
        local _active_hls = {}
        local _inactive_hls = {}
        logger.info("Compiling Active and Inactive Local Highlight Groups")
        for _, hl in pairs(M.highlights) do
            table.insert(_active_hls, hl:associate())
            table.insert(_inactive_hls, hl:disassociate())
        end
        M.active_hls = table.concat(_active_hls, ',')
        M.inactive_hls = table.concat(_inactive_hls, ',')
    end
end

local function setup_timer(frequency)
    if M.__timer then return end
    logger.info("Setting Update Highlight Timer for", frequency, "seconds")
    frequency = frequency * 1000
    local callback = function()
        get_all_highlights(false)
    end
    M.__timer = COMPAT.luv.new_timer()
    M.__timer:start(frequency, frequency, function() vim.schedule(callback) end)
end

local function setup_auto_commands()
    logger.debug("Setting up auto commands")
    if not M.__augroup_id then
        M.__augroup_id = vim.api.nvim_create_augroup(M.__augroup_name, { clear = true })
        logger.debug("Setting up augroup", M.__augroup_id)
    end
    logger.debug("Setting up UIEnter Command")
    vim.api.nvim_create_autocmd('UIEnter', {
        group = M.__augroup_id,
        desc = "Sunglasses Lazy Setup",
        callback = function()
            get_all_highlights()
            if defaults.get_config().refresh_timer then
                setup_timer(defaults.get_config().refresh_timer)
            end
        end
    })
    logger.debug("Setting up WinEnter Command")
    vim.api.nvim_create_autocmd('WinEnter', {
        group = M.__augroup_id,
        desc = "Sunglasses Auto Create Window",
        callback = function(event)
            local user_config = defaults.get_config()
            local window = Window.get(-1)

            if window and window.last_hl_update < M.__last_hl_update then
                -- Only update the window if our last highlight update
                -- was after the last time this window object was updated
                window:update_hls({
                    active_hls = M.active_hls,
                    inactive_hls = M.inactive_hls
                })
            elseif not window then
                window = Window:new({
                    buffer = event.buf,
                    namespace = M.__hl_namespace,
                    excluded_filetypes = user_config.excluded_filetypes,
                    -- Only provide these if we are in global name space
                    active_hls = M.__hl_namespace == 0 and M.active_hls,
                    inactive_hls = M.__hl_namespace == 0 and M.inactive_hls
                })
            end
        end
    })
end

local function setup_user_commands()
    logger.debug("Setting up User Commands")
    logger.debug("Setting up SunglassesOn command")
    vim.api.nvim_create_user_command(
        'SunglassesOn',
        function(command)
            local force = #command.fargs > 0 and command.fargs[1] or false
            force = ((force == 'true') or (force == true) and true) or false
            local window = Window.get(-1)
            if window then
                window:shade({ force = force })
            end
        end,
        {
            nargs = '?',
            complete = function() return {false, true} end,
            desc = "Puts sunglasses on the current window"
        }
    )
    logger.debug("Setting up SunglassesOff command")
    vim.api.nvim_create_user_command(
        'SunglassesOff',
        function(command)
            local force = #command.fargs > 0 and command.fargs[1] or false
            force = ((force == 'true') or (force == true) and true) or false
            local window = Window.get(-1)
            if window then
                window:unshade({ force = force })
            end
        end,
        {
            nargs = '?',
            complete = function() return {false, true} end,
            desc = "Takes off sunglasses on the current window"
        }
    )
    logger.debug("Setting up SunglassesDisable command")
    vim.api.nvim_create_user_command(
        "SunglassesDisable", Window.global_disable,
        {
            desc = "Disables Sunglasses completely for this vim session"
        }
    )
    logger.debug("Setting up SunglassesEnable command")
    vim.api.nvim_create_user_command(
        "SunglassesEnable", Window.global_enable,
        {
            desc = "Enables Sunglasses across all windows in vim session"
        }
    )
    vim.api.nvim_create_user_command(
        "SunglassesRefresh", function() get_all_highlights(true) end,
        {
            desc = "Tells Sunglasses to refresh its shaded highlight groups."
        }
    )
end

function M.setup(opts)
    defaults.store_config(defaults.merge_config(opts))
    logger.init({filter_level = defaults.get_config().log_level})
    logger.info("Initializing Sunglasses")
    setup_hl_namespace()
    setup_auto_commands()
    setup_user_commands()
    logger.info("Sunglasses Initialization Complete")
end

return M
