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
    version = "0.3"
}

local function setup_hl_namespace()
    M.__hl_namespace = vim.api.nvim_create_namespace(M.__hl_namespace_name)
    Window.setup(M.__hl_namespace)

    logger.debug("Setting up namespace", M.__hl_namespace)
end

local function get_all_highlights(force)
    logger.trace2("Gathering all current highlights")
    local user_config = defaults.get_config()
    local highlights = vim.api.nvim_get_hl(0, {})
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
        logger.trace3("Creating new Highlight in namespace", M.__hl_namespace, new_highlight)
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
end

local function setup_timer(frequency)
    if M.__timer or frequency <= 0 then return end
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
            local refresh_timer = defaults.get_config().refresh_timer
            if not refresh_timer or refresh_timer <= 0 then
                logger.warn("Auto highlight refresher has been disabled!")
                return
            end
            setup_timer(refresh_timer)
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
    logger.debug("Setting up SunglassesEnableToggle command")
    vim.api.nvim_create_user_command(
        "SunglassesEnableToggle", Window.global_toggle,
        {
            desc = "Toggle Sunglasses across all windows in vim session"
        }
    )
    logger.debug("Setting up SunglassesRefresh command")
    vim.api.nvim_create_user_command(
        "SunglassesRefresh", function() get_all_highlights(true) end,
        {
            desc = "Tells Sunglasses to refresh its shaded highlight groups."
        }
    )
    logger.debug("Setting up SunglassesPause command")
    vim.api.nvim_create_user_command(
        "SunglassesPause", function()
            local window = Window.get(-1)
            if not window then return end
            logger.info("Manually stopping sunglasses on", window.window)
            window:disable()
        end,
        {
            desc = "Pauses Sunglasses Auto Adjuster for this window"
        }
    )
    logger.debug("Setting up SunglassesResume command")
    vim.api.nvim_create_user_command(
        "SunglassesResume", function()
            local window = Window.get(-1)
            if not window then return end
            logger.info("Manually starting sunglasses on", window.window)
            window:enable()
        end,
        {
            desc = "Resumes Sunglasses Auto Adjuster for this window"
        }
    )
    logger.debug("Setting up SunglassesToggle command")
    vim.api.nvim_create_user_command(
        "SunglassesToggle", function()
            local window = require("sunglasses.window").get(-1)
            if window:is_shaded() then
                -- Sunglasses is enabled on the window currently focused by vim
                window:unshade()
            else
                window:shade()
            end
        end,
        {
            desc = "Toggles Sunglasses on the current window"
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
