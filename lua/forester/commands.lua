local util = require("forester.util")
local Forester = require("forester.bindings")
local Job = require("plenary.job")
local config = require("forester.config")
local pickers = require("forester.pickers")
local M = {}

local insert_below = function(content)
  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, line_count, line_count, false, content)
end

local select = function(items, callback)
  if #items == 1 then
    do
      callback(items[1])
    end
  else
    do
      vim.ui.select(items, {}, function(choice)
        if choice == nil then
          do
            return
          end
        else
          do
            callback(choice)
          end
        end
      end)
    end
  end
end

local select_template = function(callback)
  -- Get all filenames with a .tree extension from the "templates" directory
  local templates_dir = vim.fn.finddir("templates", ".;")
  local filenames = vim.fn.readdir(templates_dir)

  -- Remove the '.tree' extension from each filename
  local templates = {}
  for _, file in ipairs(filenames) do
    local name = file:gsub("%.tree$", "")
    table.insert(templates, name)
  end
  select(templates, callback)
end

local select_prefix = function(callback)
  if vim.g.forester_current_config.prefixes == nil then
    do
      vim.notify(
        "Prefixes are not configured in "
          .. vim.g.forester_current_config["path"]
          .. '. Add them like this: \nprefixes = ["foo"]'
      )
    end
  else
    select(vim.g.forester_current_config.prefixes, callback)
  end
end

M.commands = {
  -- Select the forester configuration file to use
  config = function()
    local configs = config.all_configs()
    if #configs == 0 then
      vim.notify("No forester configs available in the current directory!", vim.log.levels.WARN)
    else
      pickers.pick_config(configs)
      vim.api.nvim_exec_autocmds("User", { pattern = "SwitchedForesterConfig" })
    end
    -- config.switch()
  end,

  build = function()
    local job = Job:new({ command = "forester", args = { "build", vim.g.forester_current_config } })
    job:and_then_on_success(vim.notify("Successfully built the forest"))
  end,

  browse = function()
    local trees = Forester.query_all(vim.g.forester_current_config.path)
    local t = {}
    for k, v in pairs(trees) do
      v.addr = k
      table.insert(t, v)
    end
    if #t == 0 then
      do
        vim.print("No trees found!")
      end
    end
    pickers.pick_by_title(t, {})
  end,

  new_random = function()
    select_prefix(function(choice)
      local path = config.dir_of_latest_tree_of_prefix(choice)
      local new_tree = Forester.new_random(choice, path, vim.g.forester_current_config)[1]
      vim.cmd("edit " .. new_tree)
    end)
  end,

  new = function()
    select_prefix(function(choice)
      do
        local path = config.dir_of_latest_tree_of_prefix(choice)
        local new_tree = Forester.new(choice, path, vim.g.forester_current_config)[1]
        vim.cmd("edit " .. new_tree)
      end
    end)
  end,

  template = function(args)
    local choice = args[1]
    if choice == "" then
      vim.print("Error: No template specified")
      return
    end
    select_prefix(function(pfx)
      local path = config.dir_of_latest_tree_of_prefix(choice)
      local new_tree = Forester.template(pfx, choice, path, vim.g.forester_current_config)[1]
      vim.cmd("edit " .. new_tree)
    end)
  end,

  template_search = function()
    select_template(function(choice)
      select_prefix(function(pfx)
        local path = config.dir_of_latest_tree_of_prefix(choice)
        local new_tree = Forester.template(pfx, choice, path, vim.g.forester_current_config)[1]
        vim.cmd("edit " .. new_tree)
      end)
    end)
  end,

  transclude_template = function(args)
    local choice = args[1]
    if choice == "" then
      vim.print("Error: No template specified")
      return
    end
    select_prefix(function(pfx)
      local path = config.dir_of_latest_tree_of_prefix(choice)
      local new_tree = Forester.template(pfx, choice, path, vim.g.forester_current_config)[1]
      local addr = util.filename(new_tree):match("(.+)%..+$")
      local content = { "\\transclude{" .. addr .. "}" }
      vim.api.nvim_put(content, "c", true, true)
      vim.cmd("edit " .. new_tree)
    end)
  end,

  transclude_template_search = function()
    select_template(function(choice)
      select_prefix(function(pfx)
        local path = config.dir_of_latest_tree_of_prefix(choice)
        local new_tree = Forester.template(pfx, choice, path, vim.g.forester_current_config)[1]
        local addr = util.filename(new_tree):match("(.+)%..+$")
        local content = { "\\transclude{" .. addr .. "}" }
        vim.api.nvim_put(content, "c", true, true)
        vim.cmd("edit " .. new_tree)
      end)
    end)
  end,

  transclude_new = function()
    select(vim.g.forester_current_config.prefixes, function(choice)
      do
        local path = config.dir_of_latest_tree_of_prefix(choice)
        local new_tree = Forester.new(choice, path, vim.g.forester_current_config)[1]
        local addr = util.filename(new_tree):match("(.+)%..+$")
        local content = { "\\transclude{" .. addr .. "}" }
        vim.api.nvim_put(content, "c", true, true)
        vim.cmd("edit " .. new_tree)
        -- local new_content = { "\\tag{" .. os.date("%Y-%m-%d") .. "}" }
        -- insert_below(new_content)
      end
    end)
  end,

  link_new = function()
    select(vim.g.forester_current_config.prefixes, function(choice)
      local path = config.dir_of_latest_tree_of_prefix(choice)
      local new_tree = Forester.new(choice, path)[1]
      local addr = util.filename(new_tree):match("(.+)%..+$")
      local content = { "[](" .. addr .. ")" } --  NOTE: We should improve the workflow with snippets or something similar
      vim.api.nvim_put(content, "c", true, true)
      vim.cmd("edit " .. new_tree)
    end)
  end,
}

function M.parse(args)
  local parts = vim.split(vim.trim(args), "%s+")
  if parts[1]:find("Forester") then
    table.remove(parts, 1)
  end

  if args:sub(-1) == " " then
    parts[#parts + 1] = ""
  end
  return table.remove(parts, 1) or "", parts
end

function M.cmd(cmd, args)
  local command = M.commands[cmd]
  if command == nil then
    vim.print("Invalid forester command '" .. cmd .. "'")
  elseif cmd == "config" then
    command()
  else
    local current_cfg = vim.g.forester_current_config
    if current_cfg == "" or current_cfg == vim.NIL or current_cfg == nil then
      vim.notify("No forester config file is set! Use `:Forester config` to select one", vim.log.levels.WARN)
    elseif vim.fn.executable("forester") ~= 1 then
      vim.notify("The `forester` command is not available!", vim.log.levels.WARN)
    else
      if args ~= nil then
        command(args)
      else
        command()
      end
    end
  end
end

return M
