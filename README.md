# Foreman export scripts for user-level systemd

```ruby
# Gemfile
gem "foreman-export-systemd_user"
```

then

```
bundle exec foreman export systemd-user --app <app-name>
```

Note that this may break from foreman's protocol a bit, because it starts the processes after export. It does this by running the following:
```
systemctl --user daemon-reload
loginctl enable-linger
systemctl --user enable <app-name>.target
systemctl --user restart <app-name>.target
```
After forgetting to run these steps enough times, I just decided to bake it into the export.

## Including extra systemd files

Use `--include-dir` to copy additional systemd files (drop-in overrides, extra units, timers) after generating the main units:

```
bundle exec foreman export systemd-user --app <app-name> --include-dir Procfile.systemd
```

Example directory structure:
```
Procfile.systemd/
  <app-name>-web@.service.d/
    override.conf           # Drop-in override for the web service
  <app-name>-restart.service  # Extra standalone unit
  <app-name>-restart.timer    # Timer (will be enabled and started automatically)
```

Any `.timer` files in the root of the include directory will be enabled with `--now`.

