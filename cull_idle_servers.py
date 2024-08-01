import datetime
import json
import os
import sys

from jupyterhub.services.auth import HubAuth
from tornado import gen, httpclient, ioloop

@gen.coroutine
def cull_idle_servers(api_url, api_token, timeout):
    auth_header = {"Authorization": "token {}".format(api_token)}
    now = datetime.datetime.now(datetime.UTC)
    cull_limit = now - datetime.timedelta(seconds=timeout)
    req = httpclient.HTTPRequest(
        url=api_url + "/users",
        headers=auth_header,
    )
    client = httpclient.AsyncHTTPClient()
    resp = yield client.fetch(req)
    users = json.loads(resp.body.decode("utf8", "replace"))
    futures = []
    for user in users:
        if not user["servers"]:
            continue
        for server_name, server in user["servers"].items():
            if not server["ready"]:
                continue
            last_activity = datetime.datetime.strptime(
                server["last_activity"], "%Y-%m-%dT%H:%M:%S.%fZ"
            )
            if last_activity < cull_limit:
                futures.append(
                    client.fetch(
                        httpclient.HTTPRequest(
                            url=api_url + "/users/{}/server/{}".format(
                                user["name"], server_name
                            ),
                            method="DELETE",
                            headers=auth_header,
                        )
                    )
                )
    if futures:
        yield futures

if __name__ == "__main__":
    api_url = os.environ["JUPYTERHUB_API_URL"]
    api_token = os.environ["JUPYTERHUB_API_TOKEN"]
    timeout = int(os.environ.get("JUPYTERHUB_CULL_TIMEOUT", 3600))
    ioloop.IOLoop.current().run_sync(lambda: cull_idle_servers(api_url, api_token, timeout))
