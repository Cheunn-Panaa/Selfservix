ARGO_MANIFEST_URL=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
CLUSTER_NAME=local-cluster 
INGRESS_HOST=127.0.0.1
ARGO_PASS=admin123
init:
	$(MAKE) .init-cluster
	$(MAKE) .set-ingress
	$(MAKE) .init-namespaces
#	$(MAKE) .init-traefik
	$(MAKE) .init-argo
	$(MAKE) update-pass

start:
	minikube start

setup-app-set:
	kubectl -n argocd apply -f application-set.yaml

open: .set-ingress
	@open http://argocd.${INGRESS_HOST}.nip.io
	
.init-namespaces:
	kubectl create namespace argocd

	kubectl create namespace staging

	kubectl create namespace production
#	kubectl create ns traefik-v2

.init-cluster:
	minikube start
	minikube addons enable ingress
	kubectl --namespace ingress-nginx wait \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s

.init-argo: .set-ingress
	helm repo add argo https://argoproj.github.io/argo-helm

	helm upgrade --install \
		argocd argo/argo-cd \
		--namespace argocd \
		--create-namespace \
		--set server.ingress.hosts="{argocd.${INGRESS_HOST}.nip.io}" \
		--values argo/argocd-values.yaml \
		--wait

	

update-pass: .set-ingress
	$(eval ARGO_PASS :=$(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d))
	@echo password is ${ARGO_PASS}
	argocd login \
		--insecure \
		--username admin \
		--password ${ARGO_PASS} \
		--grpc-web \
		argocd.${INGRESS_HOST}.nip.io

	argocd account update-password \
    --current-password ${ARGO_PASS} \
    --new-password admin123

.set-ingress:
	$(eval INGRESS_HOST :=$(shell minikube ip))
	$(export INGRESS_HOST=$(minikube ip))

delete:
	minikube delete

.init-traefik:
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm install --namespace=traefik-v2 traefik traefik/traefik
	kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.8/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
	kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.8/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
	kubectl apply -f traefik/dashboard.yml