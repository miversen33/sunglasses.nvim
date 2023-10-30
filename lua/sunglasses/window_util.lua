-- https://raw.githubusercontent.com/sindrets/winshift.nvim/c1c55fec41f0e27b585378ffcaf8c5f328e5efb5/lua/winshift/lib.lua
-- Thanks sindrets, very cool!
local M = {}

---@class Node : { [integer]: Node }
---@field type '"leaf"'|'"row"'|'"col"'
---@field parent Node
---@field index integer
---@field winid integer|nil

---@class VirtualNode : Node
---@field target Node

---@alias HDirection '"left"'|'"right"'
---@alias VDirection '"up"'|'"down"'


function M.process_layout(layout)
  local function recurse(parent)
    ---@type Node
    local node = { type = parent[1] }

    if node.type == "leaf" then
      node.winid = parent[2]
    else
      for i, child in ipairs(parent[2]) do
        node[#node + 1] = recurse(child)
        node[#node].index = i
        node[#node].parent = node
      end
    end

    return node
  end

  return recurse(layout)
end

---@param tree Node
---@param winid integer
function M.find_leaf(tree, winid)
  ---@param node Node
  ---@return Node
  local function recurse(node)
    if node.type == "leaf" and node.winid == winid then
      return node
    else
      for _, child in ipairs(node) do
        local target = recurse(child)
        if target then
          return target
        end
      end
    end
  end

  return recurse(tree)
end

---Get the next node in a given direction in the given leaf's closest row
---parent. Returns `nil` if there's no node in the given direction.
---@param leaf Node
---@param dir HDirection
---@return Node|nil
function M.next_node_horizontal(leaf, dir)
  local outside_parent = (dir == "left" and leaf.index == 1)
    or (dir == "right" and leaf.index == #leaf.parent)

  if leaf.parent.type == "col" or outside_parent then
    local outer_parent = leaf.parent.parent
    if not outer_parent or outer_parent.type == "col" then
      return
    end

    return outer_parent[leaf.parent.index + ((dir == "left" and -1) or 1)]
  else
    return leaf.parent[leaf.index + ((dir == "left" and -1) or 1)]
  end
end

---Get the next node in a given direction in the given leaf's closest column
---parent. Returns `nil` if there's no node in the given direction.
---@param leaf Node
---@param dir VDirection
---@return Node|nil
function M.next_node_vertical(leaf, dir)
  local outside_parent = (dir == "up" and leaf.index == 1)
    or (dir == "down" and leaf.index == #leaf.parent)

  if leaf.parent.type == "row" or outside_parent then
    local outer_parent = leaf.parent.parent
    if not outer_parent or outer_parent.type == "row" then
      return
    end

    return outer_parent[leaf.parent.index + ((dir == "up" and -1) or 1)]
  else
    return leaf.parent[leaf.index + ((dir == "up" and -1) or 1)]
  end
end

function M.get_layout_tree()
  return M.process_layout(vim.fn.winlayout())
end

function M.get_window_neighbors(winid)
    winid = winid or vim.api.nvim_get_current_win()
    local tree = M.get_layout_tree()
    local window = M.find_leaf(tree, winid)
    local neighbors = {
        left = nil,
        top = nil,
        right = nil,
        bottom = nil
    }
    if not window then
        return neighbors
    end
    local top = M.next_node_vertical(window, "up")
    local bottom = M.next_node_vertical(window, "down")
    local left = M.next_node_horizontal(window, "left")
    local right = M.next_node_horizontal(window, "right")
    neighbors.top = top and top.winid or nil
    neighbors.bottom = bottom and bottom.winid or nil
    neighbors.left = left and left.winid or nil
    neighbors.right = right and right.winid or nil
    return neighbors
end

return M

