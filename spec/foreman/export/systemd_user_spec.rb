require "spec_helper"

RSpec.describe "foreman export systemd-user" do
  let(:container) { SystemdContainer }
  let(:app_name) { "testapp" }
  let(:systemd_dir) { container.user_systemd_dir }

  before(:all) do
    # Copy gem files to container and install
    @gem_path = SystemdContainer.copy_gem_to_container
    SystemdContainer.exec("bash", "-c", "cd #{@gem_path} && bundle install --quiet 2>&1")

    # Set up a minimal Procfile in the test user's app directory
    SystemdContainer.exec_as_user("mkdir -p /home/testuser/app")
    SystemdContainer.exec_as_user("echo 'web: ruby -run -e httpd . -p $PORT' > /home/testuser/app/Procfile")

    # Create a Gemfile in the app dir that references our gem
    SystemdContainer.exec_as_user("cat > /home/testuser/app/Gemfile << EOF
source 'https://rubygems.org'
gem 'foreman-export-systemd_user', path: '#{@gem_path}'
EOF")
    SystemdContainer.exec_as_user("cd /home/testuser/app && bundle config set --local path 'vendor/bundle' && bundle install --quiet 2>&1")
  end

  describe "basic export" do
    before(:all) do
      stdout, stderr, status = SystemdContainer.exec_as_user(
        "cd /home/testuser/app && bundle exec foreman export systemd-user --app testapp 2>&1"
      )
      @export_output = stdout
      @export_status = status
    end

    it "succeeds" do
      expect(@export_status).to be_success
    end

    it "creates the master target file" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp.target")
      expect(stdout).to include("[Unit]")
      expect(stdout).to include("testapp-web.target")
    end

    it "creates the process target file" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp-web.target")
      expect(stdout).to include("[Unit]")
    end

    it "creates the process service template" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp-web@.service")
      expect(stdout).to include("[Service]")
      expect(stdout).to include("ExecStart=")
    end

    it "creates the target.wants directory with symlinks" do
      stdout, _, _ = container.exec_as_user("ls -la #{systemd_dir}/testapp-web.target.wants/")
      expect(stdout).to include("testapp-web@")
      expect(stdout).to include("-> ../testapp-web@.service")
    end

    it "runs daemon-reload" do
      expect(@export_output).to include("systemctl --user daemon-reload")
    end

    it "enables linger" do
      expect(@export_output).to include("loginctl enable-linger")
    end

    it "enables the target" do
      expect(@export_output).to include("systemctl --user enable testapp.target")
    end

    it "the target can be started" do
      stdout, _, _ = container.exec_as_user("systemctl --user start testapp.target && systemctl --user is-active testapp.target")
      expect(stdout.strip).to eq("active")
    end
  end

  describe "with --include-dir" do
    before(:all) do
      # Create include-dir with drop-in and timer
      SystemdContainer.exec_as_user("mkdir -p /home/testuser/app/Procfile.systemd/testapp-web@.service.d")
      SystemdContainer.exec_as_user("echo '[Service]\nEnvironment=EXTRA=value' > /home/testuser/app/Procfile.systemd/testapp-web@.service.d/override.conf")

      # Create a simple timer
      SystemdContainer.exec_as_user("cat > /home/testuser/app/Procfile.systemd/testapp-cleanup.timer << 'EOF'
[Unit]
Description=Cleanup timer

[Timer]
OnCalendar=daily

[Install]
WantedBy=timers.target
EOF")

      SystemdContainer.exec_as_user("cat > /home/testuser/app/Procfile.systemd/testapp-cleanup.service << 'EOF'
[Unit]
Description=Cleanup service

[Service]
Type=oneshot
ExecStart=/bin/true
EOF")

      # Stop any existing target first
      SystemdContainer.exec_as_user("systemctl --user stop testapp.target 2>/dev/null || true")

      # Run export with --include-dir
      stdout, stderr, status = SystemdContainer.exec_as_user(
        "cd /home/testuser/app && bundle exec foreman export systemd-user --app testapp --include-dir Procfile.systemd 2>&1"
      )
      @export_output = stdout
      @export_status = status
    end

    it "succeeds" do
      expect(@export_status).to be_success
    end

    it "copies the drop-in directory" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp-web@.service.d/override.conf")
      expect(stdout).to include("EXTRA=value")
    end

    it "copies the timer file" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp-cleanup.timer")
      expect(stdout).to include("OnCalendar=daily")
    end

    it "copies the service file" do
      stdout, _, _ = container.exec_as_user("cat #{systemd_dir}/testapp-cleanup.service")
      expect(stdout).to include("ExecStart=/bin/true")
    end

    it "enables the timer with --now" do
      expect(@export_output).to include("systemctl --user enable --now testapp-cleanup.timer")
    end

    it "the timer is active" do
      stdout, _, _ = container.exec_as_user("systemctl --user is-active testapp-cleanup.timer")
      expect(stdout.strip).to eq("active")
    end

    it "the drop-in is applied" do
      stdout, _, _ = container.exec_as_user("systemctl --user show testapp-web@5000.service -p Environment")
      expect(stdout).to include("EXTRA=value")
    end
  end

  describe "error handling" do
    it "raises error when include-dir is not a directory" do
      stdout, _, status = container.exec_as_user(
        "cd /home/testuser/app && bundle exec foreman export systemd-user --app testapp --include-dir /nonexistent 2>&1"
      )
      expect(status).not_to be_success
      expect(stdout).to include("not a directory")
    end
  end
end
