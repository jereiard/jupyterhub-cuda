import os
import subprocess
import pwd
import grp

from jupyterhub.spawner import LocalProcessSpawner
from jupyterhub.auth import PAMAuthenticator

c = get_config()

# Base configuration
c.JupyterHub.ip = "0.0.0.0"
c.JupyterHub.port = 8000
c.JupyterHub.ssl_key = ""
c.JupyterHub.ssl_cert = ""

# Authentication
c.JupyterHub.authenticator_class = PAMAuthenticator

# Spawner
c.JupyterHub.spawner_class = LocalProcessSpawner

c.Spawner.notebook_dir = "/home/{username}/notebooks"
c.Spawner.args = ["--NotebookApp.default_url=/lab"]

# User environment
c.Spawner.env_keep = [
    "PATH",
    "PYTHONPATH",
    "CONDA_ROOT",
    "CONDA_DEFAULT_ENV",
    "VIRTUAL_ENV",
    "LANG",
    "LC_ALL",
]


def create_user_directory(username):
    home_dir = f"/home/{username}"
    notebooks_dir = f"{home_dir}/notebooks"
    env_dir = f"{home_dir}/.conda/envs"

    # Create home and notebooks directories if they don't exist
    os.makedirs(home_dir, exist_ok=True)
    os.makedirs(notebooks_dir, exist_ok=True)
    os.makedirs(env_dir, exist_ok=True)
    uid = pwd.getpwnam(username).pw_uid
    gid = grp.getgrnam(username).gr_gid

    for r, d, f in os.walk(home_dir):
        os.chown(r, uid, gid)
        os.chmod(r, 0o755)
    os.chmod(home_dir, 0o700)
    # os.chown(home_dir, uid, gid)
    # os.chown(notebooks_dir, uid, gid)

    condarc = os.path.join(home_dir, ".condarc")
    if not os.path.exists(condarc):
        with open(condarc, "wt") as f:
            f.write("envs_dirs:\n")
            f.write(f"  - {env_dir}\n")
        os.chown(condarc, uid, gid)
        os.chmod(condarc, 0o644)


def create_conda_env(username):
    home_dir = f"/home/{username}"
    env_dir = f"{home_dir}/.conda/envs/main.{username}"
    if not os.path.exists(env_dir):
        subprocess.run(
            [
                "sudo",
                "-u",
                f"{username}",
                "/opt/conda/bin/conda",
                "create",
                "-n",
                f"main.{username}",
                "python=3.12",
                "--yes",
            ],
            check=True,
        )
        subprocess.run(
            [
                "sudo",
                "-u",
                f"{username}",
                "/opt/conda/bin/conda",
                "install",
                "-n",
                f"main.{username}",
                "ipykernel",
                "jupyterhub",
                "notebook",
                "--yes",
            ],
            check=True,
        )
        subprocess.run(
            ["sudo", "-u", f"{username}", "/opt/conda/bin/conda", "clean", "-a", "-y"],
            check=True,
        )
        subprocess.run(
            ["chown", "-R", f"{username}:{username}", f"{home_dir}"], check=True
        )
        os.system(
            f'echo "source /opt/conda/bin/activate main.{username}" > /home/{username}/.bash_profile'
        )


# Hook for spawning single user notebook
def pre_spawn_hook(spawner):
    username = spawner.user.name
    spawner.environment = {
        "CUDA_VISIBLE_DEVICES": "0",  # Adjust based on your GPU setup
        "LD_LIBRARY_PATH": "/usr/local/cuda/lib64:$LD_LIBRARY_PATH",
        "PATH": "/opt/conda/bin:" + os.environ["PATH"],
        "CONDA_DEFAULT_ENV": f"main.{username}",
        "CONDA_ENVS_PATH": f"/home/{username}/.conda/envs/",
        # "CONDA_PREFIX": f"/home/{username}/.conda/envs/main.{username}",
    }
    spawner.cmd = [
        "conda",
        "run",
        "-n",
        f"main.{username}",
        "jupyterhub-singleuser",
    ]
    create_user_directory(username)
    create_conda_env(username)


c.Spawner.pre_spawn_hook = pre_spawn_hook

# CUDA and GPU settings
# c.Spawner.environment = {
#    "CUDA_VISIBLE_DEVICES": "0",  # Adjust based on your GPU setup
#    "LD_LIBRARY_PATH": "/usr/local/cuda/lib64:$LD_LIBRARY_PATH",
#    "PATH": "/opt/conda/bin:" + os.environ["PATH"],
#    "CONDA_DEFAULT_ENV": "main.{username}",
#    "CONDA_PREFIX": "/home/{username}/.conda/envs/main.{username}",
# }
# Use the base2 conda environment
# c.Spawner.cmd = ["conda", "run", "-n", "main.{username}", "jupyterhub-singleuser"]

# Admin users
c.PAMAuthenticator.admin_users = {"jereiard"}
c.PAMAuthenticator.allowed_users = {"jereiard"}
# if not os.path.exists("/home/jereiard"):
#    os.makedirs("/home/jereiard", exist_ok=True)

# Allow the admin to access user servers
c.JupyterHub.admin_access = True

# Services
c.JupyterHub.services = [
    {
        "name": "cull-idle",
        "admin": True,
        "command": "python3 /usr/local/bin/cull_idle_servers.py --timeout=3600".split(),
    }
]
# c.JupyterHub.tornado_settings = {
#    'cookie_options': {
#        'SameSite': 'None',
#        'Secure': True
#    },
#    'headers': {
#        'Access-Control-Allow-Origin': '*'
#    }
# }
c.JupyterHub.tornado_settings = {
    "xsrf_cookies": False,
}
c.JupyterHub.disable_check_xsrf = True
c.JupyterHub.cookie_max_age_days = 30
c.NotebookApp.terminado_settings = {"shell_command": ["/bin/bash"]}
