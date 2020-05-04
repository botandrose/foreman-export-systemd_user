# Foreman export scripts for user-level systemd on Ubuntu 16.04+

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
loginctl enable-linger
systemctl --user enable <app-name>.target
systemctl --user restart <app-name>.target
```
After forgetting to run these steps enough times, I just decided to bake it into the export.

