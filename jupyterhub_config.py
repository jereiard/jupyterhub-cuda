# jupyterhub_config.py
from jupyterhub.auth import PAMAuthenticator
from dockerspawner import DockerSpawner

c = get_config()

# DockerSpawner 설정
c.JupyterHub.spawner_class = "dockerspawner.DockerSpawner"
c.DockerSpawner.image = "nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04"
c.DockerSpawner.network_name = "jupyterhub_network"
c.DockerSpawner.use_internal_ip = True
# c.DockerSpawner.notebook_dir = "/home/jovyan/work"
# c.DockerSpawner.volumes = {"jupyterhub-user-{username}": "/home/jovyan/work"}
c.DockerSpawner.notebook_dir = "/data/{username}"
c.DockerSpawner.volumes = {"tljh.jereiard": "/data"}  # 공통 볼륨에 마운트
c.DockerSpawner.remove = True
c.DockerSpawner.debug = True

# JupyterHub 설정
c.JupyterHub.hub_ip = "0.0.0.0"
c.JupyterHub.port = 8000

# JupyterLab을 기본 인터페이스로 설정
c.Spawner.default_url = "/lab"

# 사용자 컨테이너에서 base2 환경을 기본으로 설정
c.Spawner.cmd = ["/opt/conda/envs/base2/bin/jupyter-labhub"]

# 사용자 인증 설정
c.JupyterHub.authenticator_class = PAMAuthenticator
c.PAMAuthenticator.admin_users = {"jereiard"}
c.Authenticator.allowed_users = {"jereiard"}
