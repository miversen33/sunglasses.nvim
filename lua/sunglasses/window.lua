local COMPAT = require('sunglasses.compat')
local logger = require("sunglasses.log")

local configured = false
local global_disabled = false
local windows = {}
local Window = {
    name = "NA",
    window = -1,
    buffer = -1,
    hl_namespace = 0,
    disabled = false,
    inactive_hls = "",
    active_hls = "",
    excluded_filetypes = {},
    excluded_filenames = {},
    last_hl_update = -1,
}

function Window.get(window_id)
    if window_id == -1 then
        window_id = vim.api.nvim_get_current_win()
    end
    return windows[window_id]
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

function Window:new(window_options)
    window_options = window_options or {}
    if not window_options.window then
        window_options.window = vim.api.nvim_get_current_win()
    end
    window_options.buffer = window_options.buffer or vim.api.nvim_win_get_buf(window_options.window)
    local new_window = Window.get(window_options.window)
    if new_window then
        new_window:config(window_options)
        return new_window
    end
    new_window = {}
    setmetatable(new_window, self)
    self.__index = self
    new_window:config(window_options)
    windows[window_options.window] = new_window
    return new_window
end

function Window:_delete()
    windows[self.window] = nil
    self = nil
end

function Window:config(window_options)
    self.name = window_options.name
    self.window = window_options.window
    self.buffer = window_options.buffer
    self.hl_namespace = window_options.namespace or self.hl_namespace
    self.excluded_filetypes = window_options.excluded_filetypes or self.excluded_filetypes
    self.active_hls = window_options.active_hls or self.active_hls
    self.inactive_hls = window_options.inactive_hls or self.inactive_hls
    self.last_hl_update = COMPAT.luv.hrtime()
end

function Window:update_hls(new_hls)
    self:config({
        window = self.window,
        buffer = self.buffer,
        active_hls = new_hls.active_hls,
        inactive_hls = new_hls.inactive_hls
    })
end

function Window:is_shaded()
    local current_namespace = vim.api.nvim_get_hl_ns({ winid = self.window })
    if current_namespace == self.hl_namespace and self.hl_namespace ~= 0 then
        return true
    end
    local winhighlights = vim.api.nvim_get_option_value('winhighlight', {win = self.window, scope = 'local'})
    local is_shaded = false
    -- Iterate up to the first 10 hls. Its not a huge deal
    -- "how" many we iterate over, but doing more than the first 10 or so 
    -- should mostly guarantee that we hit a SunglassesShaded highlight group
    -- if it exists. If it doesn't in the first 10, we likely aren't shaded
    local iter_limit = 10
    local iter_count = 0
    for hl_pair in winhighlights:gmatch('([^,]+)') do
        iter_count = iter_count + 1
        local from, to
        for hl in hl_pair:gmatch('([^:]+)') do
            if not from then
                from = hl
            else
                to = hl
            end
        end
        if from and from:match('^SunglassesShaded') then
            is_shaded = false
            break
        end
        if to and to:match('^SunglassesShaded') then
            is_shaded = true
            break
        end
        if iter_count >= iter_limit then
            break
        end
    end
    return is_shaded
end

function Window:can_shade()
    if global_disabled then
        return "globally disabled"
    end
    if self.disabled then
        return "currently disabled"
    end
    if not self.inactive_hls and self.hl_namespace ~= 0 then
        return "setting up"
    end
    if self:is_shaded() then
        return "currently shaded"
    end
    local buffer = self.buffer
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
    return true
end

function Window:shade(opts)
    opts = opts or {}
    local force = opts.force
    if not force and not self:can_shade() then
        return
    end
    if self.hl_namespace == 0 then
        if not self.inactive_hls or self.inactive_hls == '' then
            logger.warn("Look I know you want me to put on these awesome sunglasses but we have none to put on!")
            return
        end
        vim.api.nvim_command('setlocal winhighlight=' .. self.inactive_hls)
    else
        vim.api.nvim_win_set_hl_ns(self.window, self.hl_namespace)
    end

end

function Window:unshade(opts)
    opts = opts or {}
    local force = opts.force
    if not force and not self:is_shaded() then
        return
    end
    if not self.hl_namespace then
        if not self.active_hls or self.active_hls == '' then
            logger.warn("Look I know you want me to take off these awesome sunglasses but we don't have other things to put over our eyes!")
        end
        vim.api.nvim_command('setlocal winhighlight=' .. self.active_hls)
    else
        vim.api.nvim_win_set_hl_ns(self.window, 0)
    end
end

function Window:disable()
    self.disabled = true
end

function Window:enable()
    self.disabled = false
end

if not configured then
    -- Do basic window configurations
    vim.api.nvim_create_augroup('Sunglasses_Window_Autocommands', {
        clear = true
    })
    -- Listen for filetype changes 
    -- filtered specifically on buffers associated
    -- with windows we are watching
    vim.api.nvim_create_autocmd('FileType', {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Filetype Watcher",
        callback = function(event)
            local buffer = event.buf
            local filename = vim.fn.bufname(buffer)
            local window = Window.get(-1)
            if not window then
                logger.trace3("Ignoring Filetype change on buffer", buffer, "as it's not a tracked sunglasses window")
                return
            end
            local can_shade_window = window:can_shade()
            if can_shade_window == true then
                return
            end
            window:disable()
            logger.trace("Disabling window shading for", filename, "due to it being", can_shade_window)
        end,
    })
    vim.api.nvim_create_autocmd({'WinEnter', 'BufEnter'}, {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Auto Shader",
        callback = function()
            local winnr = vim.api.nvim_get_current_win()
            local buffer = vim.api.nvim_win_get_buf(winnr)
            local window = Window.get(winnr)
            if not window then
                logger.trace3("Ignoring window", winnr, "as it's not a tracked sunglasses window")
                return
            end
            if window.buffer ~= buffer then
                window.buffer = buffer
            end
            window:unshade()
        end
    })
    vim.api.nvim_create_autocmd("WinLeave", {
        group = "Sunglasses_Window_Autocommands",
        desc = "Sunglasses Buffer Auto Unshader",
        callback = function()
            -- TODO: Something about how closing buffers with Neo-tree works that
            -- is preventing WinLeave from being thrown...
            local winnr = vim.api.nvim_get_current_win()
            local buffer = vim.api.nvim_win_get_buf(winnr)
            local filename = vim.fn.bufname(buffer)
            local window = Window.get(winnr)
            if not window then
                logger.trace3("Ignoring window", winnr, "as it's not a tracked sunglasses window")
                return
            end
            local can_shade_window = window:can_shade()
            if can_shade_window ~= true then
                logger.trace3("Ignoring auto shade request for buffer", filename, "as its", can_shade_window)
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
            local winnr = vim.api.nvim_get_current_win()
            local window = Window.get(winnr)
            if not window then
                return
            end

        end
    })

    configured = true
end

return Window
