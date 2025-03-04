local M = {}
-- Exposing the various submodules
M.parseconf = require("rsync.parseconf")
M.cmd = require("rsync.cmd")

-- Setting up the nvim user commands
local _notify_args = function()
	return {
		hide_from_history = false,
		replace = M._parse_notify,
		title = "rsync.nvim - configurations",
		timeout = 5000,
		icon = "",
	}
end
M._parse_notify = vim.notify("", nil, _notify_args())
M.rsync_notify = function(msg, level)
	M._parse_notify = vim.notify(msg, level, _notify_args())
end

local run_single = function(target_name, dry_run)
	local rsync_config = M.parseconf.rsync_config()
	if rsync_config == nil then
		return
	end
	for _, target in pairs(rsync_config.remote_hosts) do
		if target_name == target.name or target_name == "all" then
			M.cmd.run_rsync_single(rsync_config.base_dir, target, dry_run)
			break
		end
	end
end

local complete_target = function(arglead, cmdline, cursorpos)
	local comp_targets = {}
	-- Looking over all targets
	for _, name in pairs(M.parseconf.rsync_target_list()) do
		if string.sub(name, 0, #arglead) == arglead then
			table.insert(comp_targets, name)
		end
	end
	-- Adding the potential "all" flag
	if string.sub("all", 0, #arglead) == arglead then
		table.insert(comp_targets, "all")
	end

	return comp_targets
end

M._setup_user_commands = function()
	vim.api.nvim_create_user_command("RsyncShowConfig", function()
		local rsync_local_base = M.parseconf.rsync_local_base()
		if rsync_local_base ~= nil then
			local msg_string = (
				"Working with config at ["
				.. rsync_local_base
				.. "/.rsync.json"
				.. "]\n"
				.. vim.inspect(M.parseconf.rsync_config())
			)
			M.rsync_notify(msg_string, nil)
		else
			M.rsync_notify("No configurations found", nil)
		end
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("RsyncDryRun", function(opt)
		run_single(opt.fargs[1], true)
	end, { nargs = 1, complete = complete_target })
	vim.api.nvim_create_user_command("RsyncRun", function(opt)
		run_single(opt.fargs[1], false)
	end, { nargs = 1, complete = complete_target })
end

M._setup_autocmd = function()
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function(_)
			local rsync_config = M.parseconf.rsync_config()
			if rsync_config == nil then
				return
			end
			for _, target in pairs(rsync_config.remote_hosts) do
				if target.run_on_save then
					M.cmd.run_rsync_single(rsync_config.base_dir, target, false)
				end
			end
		end,
	})
end

M.setup = function(opts)
	if opts.rsync ~= nil then
		M.cmd.settings.rsync = opts.rsync
	end
	if opts.rsync_args ~= nil then
		M.cmd.settings.rsync_args = opts.rsync_args
	end

	-- Setting up user commands will be done for all configurations
	M._setup_user_commands()

	if opts.run_on_save ~= false then
		M._setup_autocmd()
	end
end

return M
