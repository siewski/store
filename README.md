#Store

<img width="900" alt="image" src="https://storage.yandexcloud.net/momo-store-data/monitoring/momo-store.JPG">





* Расположение пельменной https://siewski.ru/
* Мониторниг https://grafana.siewski.ru/ 

<img width="450" alt="image" src="https://storage.yandexcloud.net/momo-store-data/monitoring/prom.JPG">
<img width="450" alt="image" src="https://storage.yandexcloud.net/momo-store-data/monitoring/lokilogs.JPG">


* ссылки на дашборды:
* https://grafana.siewski.ru/d/efa86fd1d0c121a26444b636a3f509a8/kubernetes-compute-resources-cluster?orgId=1&refresh=10s
* https://grafana.siewski.ru/d/200ac8fdbfbb74b39aff88118e4d1c2c/kubernetes-compute-resources-node-pods?orgId=1&refresh=10s
* https://grafana.siewski.ru/d/nLJXik2Vz/new-dashboard?orgId=1

# Инфраструктура

### Terraform
Инф-ра развернута с помощью terraform. Файл main.tf сохранен в infrastructure/terraform.
Также файл состояния хранится в S3 
### Kubernetes
Необходимые для полноценной работы приложения файлы, лежат также в infrastructure/k8s/.
Для деплоя приложения  используется helm chart infrastructure/k8s/helm-chart/momo-store.
Манифест графаны расположен в infrastructure/k8s/helm-chart/manifest
Необходимые манифесты (cert-manager, sa) развернуты по иструкции yandexcloud
### Развёртывание инфраструктуры
1. Вручную создается и настаривается терраформ бакеты, пользователь и бакет для статики. Для того чтобы терраформ не удалил свой собственный стейтфайл.
2. Заполнить файл config.s3.tfbackend содержимым ключей пользователя
```bash 
access_key = "xxx"
secret_key = "xxx"
```
3. Инициализировать хранилище
```bash 
cd ~/cloud-terraform
terraform init
```
4. Применить изменения
```bash 
terraform apply
```
5. Установить cert-manager.
https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager

6. Прописать А-запись своему домену ip балансировщика. Посмотреть ip
```bash 
kubectl get svc
```
7. Если нужно удалить инфраструктуру 
```bash 
terraform destroy
```
# Развёртывание приложения
Приложение равернуто в кубернетес кластере на одной ноде. 
Порядок развёртывания приложения:
* Запускается пайплан, пайплан поделен на 3 даун стрима, backend, frontend и helm-chart
* В backend и frontend еще 4 стейджа тестирование, сборка кода, сборка контейнера, релиз
* В helm-chart 2 стейджа сборка и деплой - деблой запускается в ручную и чарт разварачивается на кластере, версии чартов прописываются вручную и хранятся в нексусе https://nexus.praktikum-services.ru/repository/momo-store-helm-a-mosievskih-07/ 
* Так же в нексусе хранятся артефакты сборок приложения https://nexus.praktikum-services.ru/repository/momo-store-mosievskikh-frontend/ 
https://nexus.praktikum-services.ru/repository/momo-store-mosievskih-backend/

<img width="900" alt="image" src="https://storage.yandexcloud.net/momo-store-data/monitoring/pipeline.JPG">

# Развёртывание мониторинга

1. Создаем неймспейс
```bash 
kubectl create ns monitoring
```

2. Добавляем репозиторий и устанавливаем прометеус и графану

```bash 
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus --set serviceMonitorsSelector.app=prometheus --set ruleSelector.app=prometheus --namespace=monitoring prometheus-community/kube-prometheus-stack
helm install  grafana --set  --namespace=monitoring prometheus-community/kube-prometheus-stack
```
3. Устанавливаем локи
```bash
helm repo add loki https://grafana.github.io/loki/charts
helm repo update
helm upgrade --install loki loki/loki-stack --namespace=monitoring
```
4. Выставляем графану наружу
```bash 
kubectl apply -f k8s/ingress-monitoring.yml
```
5. Смотрим и меняем пароль
```bash 
kubectl get secret grafana --namespace=monitoring  --template '{{index .data "admin-password" | base64decode}}'; echo
```
