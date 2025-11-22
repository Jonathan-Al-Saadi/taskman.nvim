local M = {}

-- user config
local config = {
	task_dir = nil, -- if nil → fallback to cwd
}

-- ripgrep patterns
local PATTERNS = {
	todo = "^- \\[ \\]",
	done = "^- \\[[xX]\\]",
}

local function get_task_dir()
	if config.task_dir then
		return vim.fn.expand(config.task_dir) -- handles ~
	end
	return vim.fn.getcwd()
end

--- Takes some files and parses them for tasks
---@param pattern string Search string
---@param dir string Search dir
---@return table - A table with 'tasks'
local parse_tasks = function(pattern, dir)
	local cmd = { "rg", "--vimgrep", "--glob", "*.md", pattern, dir }
	local out = vim.fn.systemlist(cmd)

	-- Use Neovim’s builtin vimgrep parser
	vim.fn.setqflist({}, "r", { title = "Tasks", lines = out })
	-- Extract parsed entries
	local items = vim.fn.getqflist()

	return { tasks = items }
end

--- Show tasks in a popup and jump on select.
---@param pattern string
---@param dir string
local show_tasks_popup = function(pattern, dir)
	local result = parse_tasks(pattern, dir)
	local tasks = result.tasks

	if #tasks == 0 then
		vim.notify("No tasks found", vim.log.levels.INFO)
		return
	end

	-- Build display strings for the popup
	local entries = {}
	local max_len = 0
	for _, item in ipairs(tasks) do
		max_len = math.max(max_len, #item.text)
	end

	for _, item in ipairs(tasks) do
		local file = vim.fn.bufname(item.bufnr)
		table.insert(entries, string.format("%-" .. max_len .. "s    %s", item.text, file))
	end

	vim.ui.select(entries, { prompt = "Tasks" }, function(choice, idx)
		if not choice or not idx then
			return
		end
		local item = tasks[idx]
		local file = vim.fn.bufname(item.bufnr)

		-- Open file and jump to location
		vim.cmd.edit(vim.fn.fnameescape(file))
		vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
	end)
end

M.setup = function(opts)
	config = vim.tbl_extend("force", config, opts or {})

	vim.api.nvim_create_user_command("TaskList", function(cmd_opts)
		local arg = cmd_opts.args
		if arg == "" then
			arg = "todo"
		end

		local pattern = PATTERNS[arg]
		if not pattern then
			vim.notify("TaskList: use :TaskList todo or :TaskList done", vim.log.levels.ERROR)
			return
		end

		local dir = get_task_dir()
		show_tasks_popup(pattern, dir)
	end, {
		nargs = "?",
		complete = function()
			return { "todo", "done" }
		end,
	})
end

return M
