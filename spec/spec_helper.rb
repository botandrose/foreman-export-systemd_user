require "open3"
require "fileutils"
require "tmpdir"

module SystemdContainer
  DOCKERFILE_PATH = File.expand_path("Dockerfile.systemd", __dir__)
  IMAGE_NAME = "foreman-export-systemd-user-test"
  CONTAINER_NAME = "foreman-export-systemd-user-test-container"
  TEST_USER = "testuser"

  class << self
    def start
      build_image
      stop

      cmd = [
        "podman", "run", "-d",
        "--name", CONTAINER_NAME,
        "--privileged",
        "-v", "/sys/fs/cgroup:/sys/fs/cgroup:rw",
        IMAGE_NAME
      ]
      run_command(cmd)
      wait_for_systemd
    end

    def stop
      system("podman", "stop", CONTAINER_NAME, out: File::NULL, err: File::NULL)
      system("podman", "rm", CONTAINER_NAME, out: File::NULL, err: File::NULL)
    end

    def exec(*command)
      cmd = ["podman", "exec", CONTAINER_NAME] + command.flatten
      stdout, stderr, status = Open3.capture3(*cmd)
      [stdout, stderr, status]
    end

    def exec_as_user(command)
      exec("su", "-", TEST_USER, "-c", command)
    end

    def user_systemd_dir
      "/home/#{TEST_USER}/.config/systemd/user"
    end

    def copy_to_container(src, dest)
      run_command(["podman", "cp", src, "#{CONTAINER_NAME}:#{dest}"])
    end

    def copy_gem_to_container(dest = "/tmp/gem")
      gem_root = File.expand_path("../..", __FILE__)

      # Copy entire gem directory (including .git for gemspec)
      copy_to_container(gem_root, dest)

      # Remove Gemfile.lock to avoid bundler version mismatch
      exec("rm", "-f", "#{dest}/Gemfile.lock")

      # Fix permissions so test user can read the gem files
      exec("chmod", "-R", "a+rX", dest)

      # Fix git safe.directory for root and test user
      exec("git", "config", "--global", "--add", "safe.directory", dest)
      exec_as_user("git config --global --add safe.directory #{dest}")

      dest
    end

    private

    def run_command(cmd)
      stdout, stderr, status = Open3.capture3(*cmd)
      raise "Command failed: #{cmd.join(' ')}\n#{stderr}" unless status.success?
      stdout
    end

    def build_image
      run_command(["podman", "build", "-t", IMAGE_NAME, "-f", DOCKERFILE_PATH, File.dirname(DOCKERFILE_PATH)])
    end

    def wait_for_systemd(timeout: 30)
      deadline = Time.now + timeout
      loop do
        stdout, _, status = exec("systemctl", "is-system-running")
        state = stdout.strip
        break if %w[running degraded].include?(state)
        raise "Timed out waiting for systemd" if Time.now > deadline
        sleep 0.5
      end
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    SystemdContainer.start
  end

  config.after(:suite) do
    SystemdContainer.stop
  end
end
