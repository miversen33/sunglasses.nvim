local CONSTANTS = {
}
local defaults = {
    filter_percent = .65,
    filter_type = "SHADE",
    log_level = "ERROR",
    refresh_timer = 5,
    excluded_filetypes = {
        "dashboard",
        "lspsagafinder",
        "packer",
        "checkhealth",
        "mason",
        "NvimTree",
        "neo-tree",
        "plugin",
        "lazy",
        "TelescopePrompt",
        "alpha",
        "toggleterm",
        "sagafinder",
        "better_term",
        "fugitiveblame",
        "starter",
        "NeogitPopup",
        "NeogitStatus",
        "DiffviewFiles",
        "DiffviewFileHistory",
        "DressingInput",
        "spectre_panel",
        "zsh",
        "registers",
        "startuptime",
        "OverseerList",
        "Outline",
        "Navbuddy",
        "noice",
        "notify",
        "saga_codeaction",
        "sagarename"
    },
    excluded_highlights = {
        -- Accepts strings as well as lua string glob patterns
        "WinSeparator",
        {"lualine_.*", glob = true},
    },
    window_can_shade_callback = nil,
}


local M = {
    __user_config = {}
}

function M.merge_config(user_config)
    user_config = user_config or {}
    return vim.tbl_deep_extend("keep", user_config, defaults)
end

function M.store_config(user_config)
    M.__user_config = user_config
    M.__user_config.filter_percent = math.max(math.min(M.__user_config.filter_percent, 1), 0)
    if M.__user_config.refresh_timer <= 0 then
        M.__user_config.refresh_timer = nil
    else
        M.__user_config.refresh_timer = math.max(M.__user_config.refresh_timer, 1)
    end
    if vim.version().major == 0 and vim.version().minor == 9 then
        -- I don't really know why we have to do this but for some reason
        -- running the highlight fetcher multiple times in
        -- nvim 0.9.0 causes the highlights to be completely lost.
        -- Makes no sense to me but... Here we are.
        M.__user_config.refresh_timer = 0
    end
end

function M.get_config()
    return M.__user_config
end

function M.is_highlight_excluded(highlight)
    local config = M.get_config()
    for _, excluded_highlight in ipairs(config.excluded_highlights) do
        local match = excluded_highlight
        local is_glob = false
        if type(excluded_highlight) == "table" then
            match = excluded_highlight[1]
            is_glob = excluded_highlight.glob
        end
        if is_glob then
            if highlight:match(match) then
                return true
            end
        else
            if highlight:find(match) then
                return true
            end
        end
    end
    return false
end


return M
