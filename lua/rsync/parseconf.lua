local M = {}

-- Helper function for the common tenary operation
local _ternary = function(cond, T, F)
	if cond then
		return T
	else
		return F
	end
end

-- Helper function to unpack lists into something that can be easily
-- concatenated
local _extend = function(dest, src)
	if src == nil or #src == 0 then
		return dest
	end
	vim.list_extend(dest, src)
	return dest
end

local _unique = function(list)
	local return_lookup = {}
	for _, v in ipairs(list) do
		return_lookup[v] = true
	end
	local return_list = {}
	for k, _ in pairs(return_lookup) do
		table.insert(return_list, k)
	end
	return return_list
end

local _check_element = function(list, value)
	for _, v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- Common configurations to be injected into each of the host configurations
-- regardless of whether the name exists or not
M.rsync_config_common_defaults = {
	-- Avoid version tracking mismatches
	exclude = { ".git/", ".git/*" },
	exclude_file = { ".gitignore" },
	run_on_save = false,
}

-- The directory from where the local base directory is. This is defined by
-- where the .rsync.json file is stored
M.rsync_local_base = function()
	return vim.fs.root(vim.api.nvim_buf_get_name(0), { ".rsync.json" })
end

-- Getting the dynamically loaded RSYNC configurations. This will convert the
-- json configuration into a common lua-table format of:
-- {
--    root_path = "absolute path of project root"
--    remote_hosts = { -- List of remote hosts, all options are expected to per host
--      {
--      name = "string for identifying target" (default to host if not specified)
--        host = "string of ssh host",
--        basedir = "path to store at remote host",
--        run_on_save = true/false flag to indicate whether the run should be executed per save
--        exclude = { "table",  "of", "exclude", "patterns" },
--        exclude_file = { "list", "of", "file", "containing", "exclude", "patterns"}
--      }
--    }
-- }
M.rsync_config = function()
	local base_dir = M.rsync_local_base()
	if base_dir == nil then
		return nil
	end
	local json_path = base_dir .. "/.rsync.json"
	local json_table = vim.json.decode(io.open(json_path, "r"):read("*all"))
	-- Preparing the main table
	local return_table = {
		base_dir = base_dir,
		remote_hosts = {},
	}
	local unique_targets = {}

	for _, remote in ipairs(json_table.remotes) do
		-- Skipping over malformed entries
		if remote.host == nil then
			remote.host = "localhost"
		end
		if remote.name == nil then
			remote.name = remote.host
		end

		-- Excluding un-process-able entries
		if remote.basedir == nil then
			vim.notify("Skipping over entry without [basedir]", vim.log.levels.WARN)
			goto continue
		end
		-- Ignoring entries that cannot be uniquely specified
		if _check_element(unique_targets, remote.name) then
			vim.notify("Skipping entry without unique name [basedir]", vim.log.levels.WARN)
			goto continue
		end
		-- Expanding out so that everything is common (File pattern is
		-- automatically expanded at root of project path)
		local exclude = M.rsync_config_common_defaults.exclude
		exclude = _extend(exclude, json_table.exclude)
		exclude = _extend(exclude, remote.exclude)
		exclude = _unique(exclude)

		-- Exclude file should be evaluated from the root_path
		local exclude_file = M.rsync_config_common_defaults.exclude_file
		exclude_file = _extend(exclude_file, remote.exclude_file)
		exclude_file = _extend(exclude_file, json_table.exclude_file)
		exclude_file = _unique(exclude_file)
		for i, v in ipairs(exclude_file) do
			if v:find("^/") == nil then
				exclude_file[i] = base_dir .. "/" .. v
			end
		end

		table.insert(return_table.remote_hosts, {
			name = remote.name,
			host = remote.host,
			basedir = remote.basedir,
			exclude = exclude,
			exclude_file = exclude_file,
			run_on_save = _ternary(
				(remote.run_on_save ~= nil),
				remote.run_on_save,
				M.rsync_config_common_defaults.run_on_save
			),
		})
		table.insert(unique_targets, remote.name)
		::continue::
	end

	return return_table
end

M.rsync_target_list = function()
	local current_config = M.rsync_config()
	local targets = {}
	for _, v in pairs(current_config.remote_hosts) do
		table.insert(targets, v.name)
	end
	return targets
end

return M
