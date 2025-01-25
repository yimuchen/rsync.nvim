# rsync.nvim

This plugin triggers a series of `rsync` command either on demand or
automatically when the buffer is being saved. When request to perform a `rsync`
operation, this plugin will look for a `.rsync.json` file relative to the
current buffer, that describes how the `rsync` process should be performed.
Notice that the location of his JSON file determines "base" directory that you
want to perform the synchronization operation.


## Installation

Currently only tested with lazy
```lua
{
    'yimuchen/rsync.nvim',
    dependencies = { 'rcarriga/nvim-notify' }, -- Not required but makes output a bit nicer
    config = function()
      require('rsync').setup {
        settings = {
          rsync = "rsync"  -- Path to rsync executable (defaults to "rsync")
          rsync_args = {"-a", "-R", "--delete"} -- Additional arguments for the rsync command
        }
        run_on_save = true -- Whether to enable run on save behavior
      }
    end,
}
```

## Usage

### Preparing the JSON file

At the base directory that you want to perform `rsync` operations, prepare a
`.rsync.json` file in the following format.

```json
{
    "exclude": [ "list", "of", "path/patterns/to", "be/excluded", "from", "rsync"]
    "exclude_file": [ "files", "listing", "exclusion", "patterns", "suchas", "gitignore"],
    "remote" : [
        {
            "host": "name-of-ssh-host",
            "basedir": "/path/to/send/directory/to",
            "run_on_save": true
        },
        {
            "host": "",
            "basedir": "/local/path/to/sync/to/",
            "run_on_save": false
        },
    ]
}
```

To check if you have the configurations correct, you can run the command
`RsyncShowConfig` to display the parsed JSON file in the message display.
Notice at this point every entry should have a unique "name" identifier which
can be used to specify which `rsync` command to run.

### Manual running

If you have a valid configuration as shown `RsynShowConfig` command, you can
then run `RsyncDryRun <name>` to display the `rsync` command that will be
executed, once you are sure this is correct, you can simply run `RsyncRun
<name>` to execute the `rsync` command proper.

### Automatic running

If you have the set `run_on_save` flag to `true` in the global setup instance,
the every time you save your working buffer the `RsyncRun` command will be
executed for all entries in your configuration where the `run_on_save` flag is
also set to `true`.

