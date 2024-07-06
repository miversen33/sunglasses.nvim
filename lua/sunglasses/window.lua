local logger = require("sunglasses.log")
local config = require("sunglasses.defaults")

local global_disabled = false
local windows = {}
local Window = {
    name = "NA",
    window = -1,
    buffer = -1,
    hl_namespace = 0,
    excluded_filetypes = {},
    excluded_filenames = {},
    last_hl_update = -1,
    configured = false,
    window_can_shade_callback = nil,
}

function Window.get(window_id)
    if window_id == -1 then
        window_id = vim.api.nvim_get_current_win()
    end
    local user_config = config.get_config()
    local window = windows[window_id]
    if not window then
        logger.trace2("Unable to find window for", window_id, "so we are creating a new instance for it")
        window = Window:new({
            namespace = Window.hl_namespace,
            excluded_filetypes = user_config.excluded_filetypes,
            window_can_shade_callback = user_config.window_can_shade_callback,
        })
    end
    return window
end

function Window.global_disable()
    logger.info("Disabling Sunglasses across all windows")
    for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        local window = Window.get(winnr)
        if window then
            window:unshade()
        end
    end
    global_disabled = true
end

function Window.global_enable()
    global_disabled = false
    logger.info("Enabling Sunglasses across all windows (except current)")
    local current_window = vim.api.nvim_get_current_win()
    for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        local window = Window.get(winnr)
        if window and winnr ~= current_window and window:can_shade() == true then
            window:shade()
        end
    end
end

function Window.global_toggle()
    if global_disabled then
        Window.global_enable()
    else
        Window.global_disable()
    end
end

function Window:delete()
    logger.trace2("Deleting window wrapper for window number", self.window)
    windows[self.window] = nil
    self = nil
end

function Window:new(window_options)
    window_options = window_options or {}
    if not window_options.window then
        window_options.window = vim.api.nvim_get_current_win()
    end
    local new_window = windows[window_options.window]
    if new_window then
        new_window:config(window_options)
        return new_window
    end
    new_window = {}
    setmetatable(new_window, self)
    self.__index = self
    new_window:config(window_options)
    new_window:enable()
    windows[window_options.window] = new_window
    vim.api.nvim_win_set_var(new_window.window, 'Sunglasses', false)
    return new_window
end

function Window:_delete()
    windows[self.window] = nil
    self = nil
end

function Window:config(window_options)
    self.name = window_options.name
    self.window = window_options.window
    self.window_can_shade_callback = window_options.window_can_shade_callback
    self.hl_namespace = window_options.namespace or self.hl_namespace
    self.excluded_filetypes = window_options.excluded_filetypes or self.excluded_filetypes
end

function Window:is_shaded()
    return vim.api.nvim_win_get_var(self.window, 'Sunglasses')
end

function Window:can_shade()
    logger.trace2("Checking if we can shade window", self.window)
    if global_disabled then
        return "globally disabled"
    end
    if vim.api.nvim_win_get_var(self.window, 'SunglassesDisabled') then
        return "currently disabled"
    end
    if not Window.hl_namespace then
    -- if not self.inactive_hls and self.hl_namespace ~= 0 then
        return "setting up"
    end
    if self:is_shaded() then
        return "currently shaded"
    end

    local diff_mode = vim.api.nvim_get_option_value('diff', { win = self.window })

    if diff_mode then
      return "currently in diff mode"
    end

    -- We should probably get the current buffer from the window instead of saving it...
    local buffer = vim.api.nvim_win_get_buf(self.window)
    local buftype = vim.api.nvim_get_option_value('filetype', {buf = buffer})
    local filename = vim.fn.bufname(buffer)
    for _, excluded_filename in ipairs(self.excluded_filenames) do
        if excluded_filename == filename then
            return "an excluded filename"
        end
    end
    for _, excluded_filetype in ipairs(self.excluded_filetypes) do
        if excluded_filetype == buftype then
            return "an excluded filetype"
        end
    end

    if self.window_can_shade_callback ~= nil and type(self.window_can_shade_callback) == "function" then
      return self.window_can_shade_callback(self.window)
    end

    return true
end

function Window:shade(opts)
    opts = opts or {}
    local force = opts.force
    if not force and not self:can_shade() then
        return
    end
    vim.api.nvim_win_set_hl_ns(self.window, self.hl_namespace)
    vim.api.nvim_win_set_var(self.window, 'Sunglasses', true)
end

function Window:unshade(opts)
    opts = opts or {}
    local force = opts.force
    if not force and not self:is_shaded() then
        return
    end
    vim.api.nvim_win_set_hl_ns(self.window, 0)
    vim.api.nvim_win_set_var(self.window, 'Sunglasses', false)

end

function Window:disable()
    logger.trace2("Disabling Window Auto Shading", self.window)
    vim.api.nvim_win_set_var(self.window, 'SunglassesDisabled', true)
end

function Window:enable()
    logger.trace2("Enabling Window Auto Shading", self.window)
    vim.api.nvim_win_set_var(self.window, 'SunglassesDisabled', false)
end

function Window.setup(namespace)
    if Window.configured then return end
    Window.hl_namespace = namespace
    -- Do basic window configurations
    vim.api.nvim_create_augroup('Sunglasses_Window_Autocommands', {
        clear = true
    })
    vim.api.nvim_create_autocmd({'WinEnter', 'BufEnter'}, {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Auto Shader",
        callback = function()
            Window.get(-1):unshade()
        end
    })
    vim.api.nvim_create_autocmd("WinLeave", {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Auto Unshader",
        callback = function()
            -- TODO: Something about how closing buffers with Neo-tree works that
            -- is preventing WinLeave from being thrown...
            local window = Window.get(-1)
            local can_shade_window = window:can_shade()
            if can_shade_window ~= true then
                local buffer = vim.api.nvim_win_get_buf(window.window)
                local filename = vim.fn.bufname(buffer)
                logger.debug("Ignoring auto shade request for buffer", filename, "as its", can_shade_window)
                -- Don't do anything with this event
                return
            end
            window:shade()
        end
    })
    vim.api.nvim_create_autocmd('WinClosed', {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Remove Window Tracking",
        callback = function()
            Window.get(-1):delete()
        end
    })
    Window.configured = true
end

return Window
