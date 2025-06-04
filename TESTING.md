# Extract models from Web Modeler

## Help
```
python python/extract.py --help
```

## Docker help
```
docker run -it --rm -e NO_GIT=true bp3global/wm-extract-deploy extract --help
```

## Good
```
python python/extract.py --model-path build --oauth2-client-id webmodeler --oauth2-client-secret SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ --host localhost:8070 --oauth2-token-url http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token --project Sample
```

## Docker good
```
docker run -it --rm --mount type=bind,src=${PWD}/build,dst=/local --workdir /local \
-e NO_GIT=true -e OAUTH2_CLIENT_ID=webmodeler -e OAUTH2_CLIENT_SECRET=SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ \
-e OAUTH2_TOKEN_URL=http://host.docker.internal:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
-e CAMUNDA_WM_HOST=host.docker.internal:8070 \
-e CAMUNDA_WM_PROJECT=Sample \
bp3global/wm-extract-deploy \
extract
```

## Docker good (deprecated)
```
docker run -it --rm --mount type=bind,src=${PWD}/build,dst=/local --workdir /local \
-e NO_GIT=true -e CAMUNDA_WM_CLIENT_ID=webmodeler -e CAMUNDA_WM_CLIENT_SECRET=SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ \
-e OAUTH2_TOKEN_URL=http://host.docker.internal:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
-e CAMUNDA_WM_HOST=host.docker.internal:8070 \
-e CAMUNDA_WM_PROJECT=Sample \
bp3global/wm-extract-deploy \
extract
```

# Deploy models to Zeebe

## Help
```
python python/deploy.py --help
```

## Docker help
```
docker run -it --rm -e NO_GIT=true bp3global/wm-extract-deploy deploy --help
```

## Good
```
python python/deploy.py --model-path build --cluster-host localhost
```

## Docker good
```
docker run -it --rm --mount type=bind,src=${PWD}/build,dst=/local --workdir /local \
-e NO_GIT=true -e ZEEBE_CLUSTER_HOST=host.docker.internal \
bp3global/wm-extract-deploy \
deploy
```

# Deploy connector templates to Web Modeler

## Help
```
python python/deploy_connector_templates.py --help
```

## Docker help
```
docker run -it --rm -e NO_GIT=true bp3global/wm-extract-deploy deploy templates --help
```

## Good
```
python python/deploy_connector_templates.py --model-path build --oauth2-client-id webmodeler --oauth2-client-secret SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ --host localhost:8070 --oauth2-token-url http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token --project Sample
```

## Docker good
```
docker run -it --rm --mount type=bind,src=${PWD}/build,dst=/local --workdir /local \
-e NO_GIT=true -e WM_CLIENT_ID=webmodeler -e WM_CLIENT_SECRET=SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ \
-e OAUTH2_TOKEN_URL=http://host.docker.internal:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
-e WM_HOST=host.docker.internal:8070 \
-e PROJECT=Sample \
bp3global/wm-extract-deploy \
extract
```

## Bad secret
```
python python/deploy_connector_templates.py --model-path build --oauth2-client-id webmodeler --oauth2-client-secret x --host localhost:8070 --oauth2-token-url http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token --project Sample
```

## Bad token host
```
python python/deploy_connector_templates.py --model-path build --oauth2-client-id webmodeler --oauth2-client-secret SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ --host localhost:8070 --oauth2-token-url http://x:18080/auth/realms/camunda-platform/protocol/openid-connect/token --project Sample
```

## Bad Web Modeler host
```
python python/deploy_connector_templates.py --model-path build --oauth2-client-id webmodeler --oauth2-client-secret SgwpyrJuv04NdLTcBzzl1cq28EbVEXDZ --host x:8070 --oauth2-token-url http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token --project Sample
```
