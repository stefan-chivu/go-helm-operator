This repo contains a template for a basic Golang REST API server supporting Websocket connections.

After cloning, use:
```
find . -type f -not -path '*/\.*' -exec sed -i 's/go-helm-operator/<package-name>/g' {} +
```
And then:
```
mv go-helm-operator <package-name>
```
