local CONSTANTS = {
}
local defaults = {
    filter_percent = .65,
    filter_type = "SHADE",
    log_level = "WARN",
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
        "qf",
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
