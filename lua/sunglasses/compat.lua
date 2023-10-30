local Compat = {
    luv = vim.luv and vim.luv or vim.loop,
    unpack = table.unpack and table.unpack or unpack,
    pack = table.pack and table.pack or function(...)
        return { n = select("#", ...), ...}
    end
}

return Compat
