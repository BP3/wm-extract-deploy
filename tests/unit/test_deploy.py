############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2026. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################

# Unit tests for deploy.py, with pyzeebe faked so that no Zeebe cluster is needed. They describe what deploy does
# today, including CONTINUE_ON_ERROR, which docs/direction.md plans to replace.

import argparse
import asyncio
import logging

import pytest

import deploy
from deploy import Deployment


def make_args(**overrides) -> argparse.Namespace:
    """The settings Deployment reads, as the option parser would give them, with no cluster chosen."""
    settings = dict(
        log_level="ERROR",
        model_path=".",
        cluster_id=None,
        cluster_region=None,
        cluster_host=None,
        cluster_port=26500,
        tenant_ids=None,
        continue_on_error=False,
        client_id=None,
        client_secret=None,
        token_url=None,
        audience=None,
        grant_type="client_credentials",
        scope=None,
    )
    settings.update(overrides)
    return argparse.Namespace(**settings)


class FakeZeebeClient:
    """Records the calls deploy makes, and fails on request."""

    def __init__(self, channel=None, fail_for=(), healthcheck_error=None, deploy_error=None):
        self.channel = channel
        self.fail_for = set(fail_for)
        self.healthcheck_error = healthcheck_error
        self.deploy_error = deploy_error
        self.deployments = []

    async def healthcheck(self):
        if self.healthcheck_error is not None:
            raise self.healthcheck_error

    async def deploy_resource(self, *resource_file_path, tenant_id=None):
        if self.deploy_error is not None:
            raise self.deploy_error
        failing = self.fail_for.intersection(str(path) for path in resource_file_path)
        if failing:
            raise RuntimeError(f"invalid resource: {sorted(failing)}")
        self.deployments.append((tuple(str(path) for path in resource_file_path), tenant_id))


@pytest.fixture
def channels(monkeypatch):
    """Replaces pyzeebe's channel functions and ZeebeClient in deploy, and records which channel was made."""
    made = []

    def channel(kind):
        def create(**kwargs):
            made.append((kind, kwargs))
            return kind
        return create

    monkeypatch.setattr(deploy, "create_camunda_cloud_channel", channel("saas"))
    monkeypatch.setattr(deploy, "create_oauth2_client_credentials_channel", channel("oauth2"))
    monkeypatch.setattr(deploy, "create_insecure_channel", channel("insecure"))
    monkeypatch.setattr(deploy, "ZeebeClient", FakeZeebeClient)
    return made


# Choosing SaaS or self-managed

def test_cluster_id_connects_to_saas(channels):
    deployment = Deployment(make_args(cluster_id="abc-123", cluster_region="bru-2",
                                      client_id="id", client_secret="secret"))

    deployment.create_zeebe_client()

    assert channels == [("saas", dict(client_id="id", client_secret="secret",
                                      cluster_id="abc-123", region="bru-2"))]
    assert deployment.zeebe_client.channel == "saas"


def test_cluster_id_wins_over_cluster_host(channels):
    # The option parser makes them mutually exclusive, but Deployment itself prefers the cluster id
    deployment = Deployment(make_args(cluster_id="abc-123", cluster_host="zeebe.local", client_id="id"))

    deployment.create_zeebe_client()

    assert [kind for kind, _ in channels] == ["saas"]


def test_cluster_host_with_client_id_connects_with_oauth2(channels):
    deployment = Deployment(make_args(cluster_host="zeebe.local", cluster_port=26501,
                                      client_id="id", client_secret="secret",
                                      token_url="http://keycloak/token", audience="zeebe-api", scope="zeebe"))

    deployment.create_zeebe_client()

    assert channels == [("oauth2", dict(grpc_address="zeebe.local:26501", client_id="id", client_secret="secret",
                                        authorization_server="http://keycloak/token", audience="zeebe-api",
                                        scope="zeebe"))]


def test_cluster_host_without_client_id_connects_insecurely(channels):
    deployment = Deployment(make_args(cluster_host="zeebe.local"))

    deployment.create_zeebe_client()

    assert channels == [("insecure", dict(grpc_address="zeebe.local:26500"))]


@pytest.mark.parametrize("cluster", [dict(), dict(cluster_host=""), dict(cluster_id="")])
def test_no_cluster_is_an_error(channels, cluster):
    deployment = Deployment(make_args(**cluster))

    with pytest.raises(ValueError, match="Cluster id or host must be specified"):
        deployment.create_zeebe_client()
    assert channels == []


# Finding the files to deploy

def write_models(root, *paths):
    for path in paths:
        file = root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("<model/>")


def deployed_files(deployment):
    return sorted(path for files, _ in deployment.zeebe_client.deployments for path in files)


def test_deploys_bpmn_dmn_and_form_files_in_subfolders_too(channels, tmp_path):
    write_models(tmp_path, "a.bpmn", "rules/b.dmn", "forms/deep/c.form", "notes.md", "d.bpmn.bak")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))

    asyncio.run(deployment.main())

    assert deployed_files(deployment) == sorted(str(tmp_path / path)
                                                for path in ("a.bpmn", "rules/b.dmn", "forms/deep/c.form"))


def test_deploys_everything_in_one_deployment(channels, tmp_path):
    write_models(tmp_path, "a.bpmn", "b.dmn", "c.form")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))

    asyncio.run(deployment.main())

    assert len(deployment.zeebe_client.deployments) == 1
    files, tenant = deployment.zeebe_client.deployments[0]
    assert len(files) == 3
    assert tenant is None


def test_nothing_to_deploy_warns_and_does_not_connect(channels, tmp_path, caplog):
    caplog.set_level(logging.WARNING)
    write_models(tmp_path, "notes.md")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))

    asyncio.run(deployment.main())

    assert "Didn't find any files to deploy" in caplog.text
    assert channels == []
    assert deployment.zeebe_client is None


# Tenants

def test_each_tenant_gets_its_own_deployment(channels, tmp_path):
    write_models(tmp_path, "a.bpmn", "b.dmn")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local",
                                      tenant_ids="tenant-a,tenant-b"))

    asyncio.run(deployment.main())

    deployments = deployment.zeebe_client.deployments
    assert sorted(tenant for _, tenant in deployments) == ["tenant-a", "tenant-b"]
    assert all(len(files) == 2 for files, _ in deployments)


def test_logs_the_tenant_it_deploys_to(channels, tmp_path, caplog):
    # #114: the tenant went into the message with str.format, leaving a %s with no argument, so each tenant's line
    # failed with "not enough arguments for format string" instead of being logged
    write_models(tmp_path, "a.bpmn")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local",
                                      tenant_ids="tenant-a,tenant-b"))
    # INFO, as the line isn't logged at the ERROR level make_args sets. caplog fails the test if a line can't be logged
    caplog.set_level(logging.INFO, logger="Deployment")

    asyncio.run(deployment.main())

    deploying = sorted(record.getMessage() for record in caplog.records
                       if record.getMessage().startswith("Deploying resources"))
    file = str(tmp_path / "a.bpmn")
    assert deploying == [f"Deploying resources: ['{file}'] to tenant tenant-a...",
                         f"Deploying resources: ['{file}'] to tenant tenant-b..."]


# CONTINUE_ON_ERROR

def test_continue_on_error_deploys_file_by_file_past_a_failure(channels, tmp_path):
    write_models(tmp_path, "a.bpmn", "bad.bpmn", "c.bpmn")
    bad = str(tmp_path / "bad.bpmn")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local", continue_on_error=True))
    deployment.create_zeebe_client()
    deployment.zeebe_client.fail_for = {bad}

    asyncio.run(deployment.deploy(sorted(str(tmp_path / name) for name in ("a.bpmn", "bad.bpmn", "c.bpmn"))))

    # One deployment per file; the failure is logged, not raised, so WMED still exits 0
    assert deployment.zeebe_client.deployments == [((str(tmp_path / "a.bpmn"),), None),
                                                   ((str(tmp_path / "c.bpmn"),), None)]


def test_without_continue_on_error_one_bad_file_fails_the_deployment(channels, tmp_path):
    write_models(tmp_path, "a.bpmn", "bad.bpmn")
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))
    deployment.create_zeebe_client()
    deployment.zeebe_client.fail_for = {str(tmp_path / "bad.bpmn")}

    with pytest.raises(RuntimeError, match="invalid resource"):
        asyncio.run(deployment.deploy([str(tmp_path / "a.bpmn"), str(tmp_path / "bad.bpmn")]))
    assert deployment.zeebe_client.deployments == []


# Exit codes

def test_unreachable_gateway_exits_with_3(channels, tmp_path, monkeypatch):
    write_models(tmp_path, "a.bpmn")
    unavailable = deploy.ZeebeGatewayUnavailableError.__new__(deploy.ZeebeGatewayUnavailableError)
    unavailable.grpc_error = "gateway unavailable"
    monkeypatch.setattr(deploy, "ZeebeClient",
                        lambda channel: FakeZeebeClient(channel, healthcheck_error=unavailable))
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))

    with pytest.raises(SystemExit) as exited:
        asyncio.run(deployment.main())
    assert exited.value.code == 3


def test_rejected_deployment_exits_with_3_and_logs_zeebes_error(channels, tmp_path, monkeypatch, caplog):
    caplog.set_level(logging.ERROR)
    write_models(tmp_path, "a.bpmn")

    # deploy logs the details of the gRPC error that pyzeebe's ProcessInvalidError was raised from
    cause = Exception()
    cause._details = "Command 'CREATE' rejected: a.bpmn is invalid"
    invalid = deploy.ProcessInvalidError()
    invalid.__cause__ = cause
    monkeypatch.setattr(deploy, "ZeebeClient", lambda channel: FakeZeebeClient(channel, deploy_error=invalid))
    deployment = Deployment(make_args(model_path=str(tmp_path), cluster_host="zeebe.local"))

    with pytest.raises(SystemExit) as exited:
        asyncio.run(deployment.main())
    assert exited.value.code == 3
    assert "a.bpmn is invalid" in caplog.text
