local logger = require("sunglasses.log")

local CONSTANTS = {
    HEX = 16,
    RGB_MAX = 255,
    RGB_MIN = 0,
}

local Highlight = {
    ADJUSTMENT_OPTIONS = {
        SATURATE = "SATURATE",
        DESATURATE = "DESATURATE",
        TINT = "TINT",
        SHADE = "SHADE",
        NOSYNTAX = "NOSYNTAX",
    },
    name = nil,
    namespace = 0,
    adjustment_level = 1,
    unshaded_highlight = nil,
    highlight = nil,
    orig_highlight = {}
}

local function clamp_color_channel(color_channel)
    return math.max(math.min(color_channel, CONSTANTS.RGB_MAX), CONSTANTS.RGB_MIN)
end

local function format_color_channel(color_channel_rgb)
    return string.format("%02x", math.floor(clamp_color_channel(color_channel_rgb)))
end

local function tint_color(color_as_int, tint_level)
    local color = string.format("%x", color_as_int)
    local color_r_raw = tonumber(color:sub(1, 2), CONSTANTS.HEX) or 0
    local color_r = format_color_channel(color_r_raw + ((255 - color_r_raw) * tint_level))
    local color_g_raw = tonumber(color:sub(3, 4), CONSTANTS.HEX) or 0
    local color_g = format_color_channel(color_g_raw + ((255 - color_g_raw) * tint_level))
    local color_b_raw = tonumber(color:sub(5, 6), CONSTANTS.HEX) or 0
    local color_b = format_color_channel(color_b_raw + ((255 - color_b_raw) * tint_level))
    local rgb_color = string.format("#%s%s%s", color_r, color_g, color_b)
    return rgb_color
end

local function shade_color(color_as_int, shade_level)
    local color = string.format("%x", color_as_int)
    local color_r = format_color_channel((tonumber(color:sub(1, 2), CONSTANTS.HEX) or 0) * (1 - shade_level))
    local color_g = format_color_channel((tonumber(color:sub(3, 4), CONSTANTS.HEX) or 0) * (1 - shade_level))
    local color_b = format_color_channel((tonumber(color:sub(5, 6), CONSTANTS.HEX) or 0) * (1 - shade_level))
    local rgb_color = string.format("#%s%s%s", color_r, color_g, color_b)
    return rgb_color
end

local function clone_highlight(highlight, resolve_links, name)
    local cloned_highlight = {}
    name = name or ""
    if type(highlight) == 'string' then
        highlight = vim.api.nvim_get_hl(0, {name = highlight})
    end
    if resolve_links and highlight.link then
        while highlight.link do
            highlight = vim.api.nvim_get_hl(0, {name = highlight.link})
        end
    end
    for key, value in pairs(highlight) do
        cloned_highlight[key] = value
    end
    cloned_highlight.bold = false
    return cloned_highlight
end

function Highlight.shade(highlight, shade_level)
    local hl = clone_highlight(highlight, true)
    if hl then
        if hl.fg then
            hl.fg = shade_color(hl.fg, shade_level)
        end
        if hl.bg then
            hl.bg = shade_color(hl.bg, shade_level)
        end
        if hl.sp then
            hl.sp = shade_color(hl.sp, shade_level)
        end
    end
    if not hl then hl = {} end
    return hl
end

function Highlight.tint(highlight, tint_level)
    local hl = clone_highlight(highlight, true)
    if hl then
        if hl.fg then
            hl.fg = tint_color(hl.fg, tint_level)
        end
        if hl.bg then
            hl.bg = tint_color(hl.bg, tint_level)
        end
        if hl.sp then
            hl.sp = tint_color(hl.sp, tint_level)
        end
    end
    if not hl then hl = {} end
    return hl
end

function Highlight.saturate(highlight, saturation_level)
    error("Saturation is not implemented yet!")
    return highlight
end

function Highlight.desaturate(highlight, desaturation_level)
    error("Desaturation is not implemented yet!")
    return highlight
end

function Highlight.disable(highlight, adjust_level)
    local hl = clone_highlight(highlight, true) or {}
    local action = "shade"
    hl.fg = 16777215 -- #ffffff
    hl.bg = nil
    hl.sp = nil
    if vim.opt.background == "light" then
        hl.fg = 0 -- #000000
        action = "tint"
    end
    return Highlight[action](hl, adjust_level)
end

function Highlight:associate()
    return string.format("%s:%s", self.unshaded_highlight, self.name)
end

function Highlight:disassociate()
    return string.format("%s:%s", self.name, self.unshaded_highlight)
end

function Highlight:apply(force)
    local existing_hl = vim.api.nvim_get_hl(self.namespace, {name = self.name})
    if not vim.tbl_isempty(existing_hl) then
        if not force then return end
        logger.warn("Forcibly overriding existing highlight", self.name)
    end
    vim.api.nvim_set_hl(self.namespace, self.name, self.highlight)
end

function Highlight:new(highlight_options)
    highlight_options = highlight_options or {}
    assert(highlight_options.highlight, "missing highlight")
    local new_highlight = {}
    self.__index = self
    setmetatable(new_highlight, self)
    new_highlight.orig_highlight = highlight_options.highlight
    new_highlight.adjustment = highlight_options.adjustment or Highlight.ADJUSTMENT_OPTIONS.SHADE
    new_highlight.adjustment_level = highlight_options.adjustment_level or Highlight.adjustment_level
    new_highlight.namespace = highlight_options.namespace or 0
    local name = highlight_options.name and highlight_options.name
        or highlight_options.highlight
    if new_highlight.namespace ~= 0 then
        -- If a namespace is provided we will simply override the existing values in that
        -- namespace
        new_highlight.name = name
    else
        -- Otherwise we do some weirdness with new highlight groups
        new_highlight.name = string.format("SunglassesShaded_%s", name)
    end
    new_highlight.unshaded_highlight = name
    local resolve_highlight_links = highlight_options.resolve_links and true or false
    new_highlight.highlight = clone_highlight(highlight_options.highlight, resolve_highlight_links, name)
    if new_highlight.adjustment == Highlight.ADJUSTMENT_OPTIONS.NOSYNTAX then
        new_highlight.highlight = Highlight.disable(new_highlight.highlight, new_highlight.adjustment_level)
    elseif new_highlight.adjustment == Highlight.ADJUSTMENT_OPTIONS.SHADE then
        new_highlight.highlight = Highlight.shade(new_highlight.highlight, new_highlight.adjustment_level)
    elseif new_highlight.adjustment == Highlight.ADJUSTMENT_OPTIONS.TINT then
        new_highlight.highlight = Highlight.tint(new_highlight.highlight, new_highlight.adjustment_level)
    elseif new_highlight.adjustment == Highlight.ADJUSTMENT_OPTIONS.SATURATE then
        new_highlight.highlight = Highlight.saturate(new_highlight.highlight, new_highlight.adjustment_level)
    elseif new_highlight.adjustment == Highlight.ADJUSTMENT_OPTIONS.DESATURATE then
        new_highlight.highlight = Highlight.desaturate(new_highlight.highlight, new_highlight.adjustment_level)
    end
    new_highlight:apply()
    return new_highlight
end

return Highlight
