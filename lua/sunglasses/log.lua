local COMPAT = require("sunglasses.compat")
local CONSTANTS = {
    LOG_LOCATION = vim.fn.stdpath('log') .. '/sunglasses.log',
    LOG_FMT = "$TIMESTAMP [Session: $SESSION_ID] [Logger: $LOG_NAME] [Level: $LOG_LEVEL] -- $SOURCE $MESSAGE",
    TIMESTAMP_FMT = "%Y-%m-%d %H:%M:%S",
    FILTER_LEVEL = "ERROR",
    SOURCE_OFFSET = 3,
    NAME = "Sunglasses",
    LEVELS = {
        CRITICAL = {
            map_level = 4,
            real_level = 0,
            name = "CRITICAL",
            display = true
        },
        ERROR = {
            map_level = 4,
            real_level = 1,
            name = "ERROR",
            display = true
        },
        WARN = {
            map_level = 3,
            real_level = 2,
            name = "WARN",
        },
        INFO = {
            map_level = 2,
            real_level = 3,
            name = "INFO",
        },
        DEBUG = {
            map_level = 1,
            real_level = 4,
            name = "DEBUG",
        },
        TRACE = {
            map_level = 0,
            real_level = 5,
            name = "TRACE",
        },
        TRACE2 = {
            map_level = 0,
            real_level = 6,
            name = "TRACE2",
        },
        TRACE3 = {
            map_level = 0,
            real_level = 7,
            name = "TRACE3"
        }
    }
}

local function map_level(level)
    if type(level) == 'string' then
        local l = string.upper(level)
        local mapped_level = nil
        for key, matched_level in pairs(CONSTANTS.LEVELS) do
            if key == l then
                mapped_level = matched_level
                break
            end
        end
        if not mapped_level then
            -- TODO: Complain?
            mapped_level = CONSTANTS.LEVELS.DEBUG
        end
        level = mapped_level
    end
    if type(level) == 'number' then
        local mapped_level = nil
        for _, matched_level in pairs(CONSTANTS.LEVELS) do
            if matched_level.real_level == level then
                mapped_level = matched_level
                break
            end
        end
        if not mapped_level then
            -- TODO: Complain?
            mapped_level = CONSTANTS.LEVELS.DEBUG
        end
        level = mapped_level
    end
    return level
end

local function format_log_string(log_info, log_format_string, append_newline)
    log_info = log_info or {}
    local keys = {
        ["$TIMESTAMP"] = log_info.timestamp or "",
        ["$LOG_NAME"] = log_info.log_name or "",
        ["$LOG_LEVEL"] = log_info.log_level or "",
        ["$SOURCE"] = log_info.source or "",
        ["$MESSAGE"] = log_info.message or "",
        ["$SESSION_ID"] = log_info.session_id or ""
    }
    local formatted_string = log_format_string
    for key, replacement in pairs(keys) do
        formatted_string = formatted_string:gsub(key, replacement)
    end
    if append_newline then
        formatted_string = formatted_string .. "\n"
    end
    return formatted_string
end

local function join_log_parts(...)
    local data = {}
    local message = COMPAT.pack(...)
    for i=1, message.n do
        local msg_item = message[i]
        if type(msg_item) == 'table' then
            table.insert(data, vim.inspect(msg_item, {newline = '\n'}))
        else
            table.insert(data, string.format('%s', msg_item))
        end
    end
    if #data == 0 then
        -- Nothing to do 
        return ""
    end
    return table.concat(data, ' ')
end

local M = {
    __dun = false,
}

function M.config(opts)
    opts = opts or {}
    M.__log_name = opts.name or M.__log_name or CONSTANTS.NAME
    M.__log_location = opts.location or M.__log_location or CONSTANTS.LOG_LOCATION
    M.__log_fmt = opts.fmt or M.__log_fmt or CONSTANTS.LOG_FMT
    M.__timestamp_fmt = opts.timestamp_fmt or M.__timestamp_fmt or CONSTANTS.TIMESTAMP_FMT
    M.__filter_level = opts.filter_level or M.__filter_level or CONSTANTS.FILTER_LEVEL
    M.__filter_level = map_level(M.__filter_level)
    if M.__log_handle then
        M.__log_handle:flush()
        M.__log_handle:close()
        M.__log_handle = nil
    end
    M.__log_handle = io.open(M.__log_location, 'a+')
    assert(M.__log_handle, string.format("Unable to open log file %s!", M.__log_location))
end

function M.init(opts)
    M.config(opts)
    if M.__dun then return end
    local session_id = ""
    for _ = 1, 15 do
        session_id = session_id .. string.char(math.random(97,122))
    end
    M.__session_id = session_id
    vim.api.nvim_create_autocmd("VimLeave", {
        pattern = {"*"},
        callback = function(event)
            if M.__log_handle then
                io.close(M.__log_handle)
                M.__log_handle = nil
            end
            if event.id then
                vim.api.nvim_del_autocmd(event.id)
            end
        end
    })
    M.__dun = true
end

function M.log(message, level, source_offset)
    if not M.__dun then
        M.init()
    end
    level = level and map_level(level) or CONSTANTS.LEVELS.DEBUG
    if level.real_level > M.__filter_level.real_level then
        -- Nothing to do here
        return
    end
    source_offset = source_offset or 3
    local timestamp = os.date(M.__timestamp_fmt)
    local stack_info = debug.getinfo(source_offset, 'Sln')
    local log_name = M.__log_name
    local source = string.format("%s:%s:%s", stack_info.short_src, stack_info.name, stack_info.currentline)
    local formatted_log = format_log_string({
        timestamp = timestamp,
        log_name = log_name,
        session_id = M.__session_id,
        log_level = level.name,
        source = source,
        message = message,
    }, M.__log_fmt, true)
    if level.display then
        vim.notify(message, level.mapped_level)
    end
    if not M.__log_handle then
        -- Complain?
        return
    end
    M.__log_handle:write(formatted_log)
    M.__log_handle:flush()
end

function M.critical(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.CRITICAL, CONSTANTS.SOURCE_OFFSET)
end

function M.error(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.ERROR, CONSTANTS.SOURCE_OFFSET)
end

function M.warn(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.WARN, CONSTANTS.SOURCE_OFFSET)
end

function M.info(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.INFO, CONSTANTS.SOURCE_OFFSET)
end

function M.debug(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.DEBUG, CONSTANTS.SOURCE_OFFSET)
end

function M.trace(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.TRACE, CONSTANTS.SOURCE_OFFSET)
end

function M.trace2(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.TRACE2, CONSTANTS.SOURCE_OFFSET)
end

function M.trace3(...)
    M.log(join_log_parts(...), CONSTANTS.LEVELS.TRACE3, CONSTANTS.SOURCE_OFFSET)
end



return M
