#!/usr/bin/python3

import re
import subprocess
import sys

def get_config_from_cli():
    config = {}
    try:
        command = 'eval "$(/usr/bin/cli-shell-api getEditResetEnv)" && /usr/bin/cli-shell-api showCfg service tailscale'
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            executable='/bin/bash'
        )

        if "Specified configuration path is not valid" in result.stdout or \
           "Specified configuration path is not valid" in result.stderr:
            return {}

        if result.returncode != 0:
            result.check_returncode()

        output = result.stdout.strip()
        if not output:
            return {}

        lines = output.split('\n')
        in_advertise_block = False
        for line in lines:
            clean_line = line.lstrip(' +->').strip()
            if not clean_line:
                continue

            if clean_line == 'advertise {':
                in_advertise_block = True
                continue

            if clean_line == '}':
                in_advertise_block = False
                continue

            parts = clean_line.split(None, 1)
            key = parts[0]
            value = parts[1] if len(parts) > 1 else True

            if key in config:
                if isinstance(config[key], list):
                    config[key].append(value)
                else:
                    config[key] = [config[key], value]
            else:
                config[key] = value

        return config
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise Exception(f"Failed to execute cli-shell-api: {e}")
    except Exception as e:
        raise Exception(f"An unexpected error occurred in get_config_from_cli: {e}")

def generate_cli_args(config):
    """Generate tailscale CLI arguments from config"""
    # The 'up' command can be used to both login and update an existing session.
    args = ['up']

    if 'ignore-dns' in config:
        args.append('--accept-dns=false')
    else:
        args.append('--accept-dns')

    if 'exit-node' in config:
        args.append('--advertise-exit-node')

    if 'route' in config:
        if isinstance(config['route'], list):
            routes = ','.join(config['route'])
        else:
            routes = config['route']
        args.append(f'--advertise-routes={routes}')

    if 'tag' in config:
        if isinstance(config['tag'], list):
            tags = ','.join([f"tag:{tag}" for tag in config['tag']])
        else:
            tags = f"tag:{config['tag']}"
        args.append(f'--advertise-tags={tags}')

    if 'auth-key' in config:
        args.append(f"--auth-key={config['auth-key']}")

    if 'hostname' in config:
        args.append(f"--hostname={config['hostname']}")

    if 'netfilter-mode' in config:
        args.append(f"--netfilter-mode={config['netfilter-mode']}")

    if 'shields-up' in config:
        args.append('--shields-up')

    if 'stop-snat-subnet-routes' in config:
        args.append('--snat-subnet-routes=false')
    else:
        args.append('--snat-subnet-routes')

    if 'ssh' in config:
        args.append('--ssh')

    if 'stateful-filtering' in config:
        args.append('--stateful-filtering')

    if 'timeout' in config:
        args.append(f"--timeout={config['timeout']}")

    return args

if __name__ == "__main__":
    try:
        config = get_config_from_cli()

        # If no config, do nothing and exit gracefully
        if not config:
            print("No Tailscale configuration found, skipping.")
            sys.exit(0)

        # If auth-key is missing, attempt a logout, then a down, ignoring errors.
        if 'auth-key' not in config:
            print("Auth-key not found. Attempting to log out and bring connection down.")
            logout_result = subprocess.run(['sudo', '/config/tailscale/tailscale', 'logout'], capture_output=True, text=True)
            # If logout failed (e.g., already logged out), try bringing the connection down.
            if logout_result.returncode != 0:
                subprocess.run(['sudo', '/config/tailscale/tailscale', 'down'], capture_output=True, text=True)
            # Exit gracefully after cleanup attempt
            sys.exit(0)
        else:
            # Otherwise, run 'up' with the current config
            args = generate_cli_args(config)
            command = ['sudo', '/config/tailscale/tailscale'] + args
            result = subprocess.run(command, capture_output=True, text=True)
            # If the command failed, print the error and exit
            if result.returncode != 0:
                if result.stderr:
                    print(result.stderr, file=sys.stderr)
                sys.exit(result.returncode)

        # Run the status command and print the output
        status_command = ['sudo', '/config/tailscale/tailscale', 'status']
        status_result = subprocess.run(status_command, capture_output=True, text=True)

        if status_result.stdout:
            print("Tailscale status:")
            print(status_result.stdout)
        if status_result.stderr:
            print(status_result.stderr, file=sys.stderr)

        sys.exit(status_result.returncode)

    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)
