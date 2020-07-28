# To Deploy Nginx Ingress Helm Chart
helm install --namespace dev stable/nginx-ingress --name dev-internal-nginx \
--set rbac.create=true \
--set controller.scope.namespace=dev \
--set controller.ingressClass="internal-ingress" \
--set controller.stats.enabled=true \
--set controller.metrics.enabled=true \
--set controller.publishService.enabled=true \
--set controller.replicaCount=1 \
--set serviceAccount.create=true \
--set controller.service.nodePorts.http=30080 \
--set controller.service.nodePorts.https=30443 \
--set controller.scope.enabled=false \
-f internal-annotation-values.yaml \
-f internal-values.yaml
