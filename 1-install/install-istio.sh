#!/bin/bash

WORKDIR="/Users/mokeefe"
ISTIO_VERSION=1.4.0

kubectl create namespace istio-system

kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value core/account)

helm template ${WORKDIR}/istio-${ISTIO_VERSION}/install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f -
sleep 20

kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l

sleep 1

helm template ${WORKDIR}/istio-${ISTIO_VERSION}/install/kubernetes/helm/istio --name istio --namespace istio-system \
--set prometheus.enabled=true \
--set tracing.enabled=true \
--set kiali.enabled=true --set kiali.createDemoSecret=true \
--set "kiali.dashboard.jaegerURL=http://jaeger-query:16686" \
--set "kiali.dashboard.grafanaURL=http://grafana:3000" \
--set grafana.enabled=true \
--set global.proxy.accessLogFile="/dev/stdout" \
--set values.global.mtls.auto=true \
--set values.global.mtls.enabled=false \
--set mixer.policy.enabled=false \
--set mixer.telemetry.enabled=false > istio.yaml

# install istio
kubectl apply -f istio.yaml

# enable mixer-less telemetry
kubectl -n istio-system get cm istio -o yaml | sed -e 's/disableMixerHttpReports: false/disableMixerHttpReports: true/g' | kubectl replace -f -
kubectl -n istio-system apply -f https://raw.githubusercontent.com/istio/proxy/release-1.4/extensions/stats/testdata/istio/metadata-exchange_filter.yaml
kubectl -n istio-system apply -f https://raw.githubusercontent.com/istio/istio/release-1.4/tests/integration/telemetry/stats/prometheus/testdata/stats_filter.yaml
kubectl -n istio-system apply -f https://raw.githubusercontent.com/istio/proxy/release-1.4/extensions/stackdriver/testdata/stackdriver_filter.yaml