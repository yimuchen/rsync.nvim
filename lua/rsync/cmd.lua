local M = {}
-- Simple function for performing string concatenation, similar to what is done
-- for python string.join
local _joinstr = function(list, delim)
	local return_str = ""
	for _, v in ipairs(list) do
		if return_str == "" then
			return_str = v
		else
			return_str = return_str .. delim .. v
		end
	end
	return return_str
end

M.settings = {
	rsync = "rsync",
	rsync_args = {
		"-a", -- # rsync in archive mode
		"-r", -- # Recursive,
		"--delete", -- Deleting files if there are extra files
	},
}

M.make_rsync_cmds = function(local_base, remote_host_config)
	-- For a given remote host configuration, return the rsync command to be ran
	--as a list of strings
	local exclude_tokens = {}
	for _, pattern in ipairs(remote_host_config.exclude) do
		table.insert(exclude_tokens, "--exclude=" .. pattern)
	end

	local cmd = { M.settings.rsync }
	vim.list_extend(cmd, M.settings.rsync_args)
	vim.list_extend(cmd, exclude_tokens)
	local cmd_exclude_file = {}
	for _, file in pairs(remote_host_config.exclude_file) do
		if vim.loop.fs_stat(file) ~= nil then
			vim.list_extend(cmd_exclude_file, { file })
		end
	end
	if next(cmd_exclude_file) ~= nil then
		vim.list_extend(cmd, { "--exclude-from=" .. _joinstr(cmd_exclude_file, ",") })
	end
	vim.list_extend(cmd, {
		local_base .. "/",
		remote_host_config.host .. ":" .. remote_host_config.basedir,
	})

	return cmd
end

-- Queue for storing the commands to run
M.notify_args = function()
	return {
		hide_from_history = false,
		replace = M.notification,
		title = "Rsync.nvim - execution",
		timeout = 3000, -- 3 seconds
		icon = "󰓦",
	}
end
M.notification = vim.notify("", nil, M.notify_args())
M.notify = function(msg, level)
	M.notification = vim.notify(msg, level, M.notify_args())
end

M.run_rsync_single = function(local_base, remote_host_config, dry_run)
	local cmd = M.make_rsync_cmds(local_base, remote_host_config)
	local msg = "Start sync to [" .. remote_host_config.host .. "]"
	M.notify(msg, vim.log.levels.INFO)

	if dry_run then
		msg = "Expected command [" .. _joinstr(cmd, " ") .. "]"
		M.notify(msg, vim.log.levels.INFO)
	else
		local stderr = {}
		local stdout = {}
		vim.fn.jobstart(cmd, {
			on_stderr = function(_, data, _)
				if data == nil or #data == 0 then
					return
				end
				vim.list_extend(stderr, data)
			end,
			on_stdout = function(_, data, _)
				if data == nil or #data == 0 then
					return
				end
				vim.list_extend(stdout, data)
			end,
			on_exit = function(_, code, _)
				if code ~= 0 then
					msg = " Error syncing to [" .. remote_host_config.host .. "]"
					M.notify(msg, vim.log.levels.ERROR)
				else
					msg = " Complete rsync to [" .. remote_host_config.host .. "]"
					M.notify(msg, vim.log.levels.INFO)
				end
			end,
		})
	end
end

return M
