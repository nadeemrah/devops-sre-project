# Namespace for logging (fluentd)
resource "kubernetes_namespace" "logging" {
  provider = kubernetes.generated
  metadata {
    name = "logging"
    labels = { name = "logging" }
  }
  depends_on = [module.eks]
}

# Fluentd ConfigMap 
resource "kubernetes_config_map" "fluentd_config" {
  provider = kubernetes.generated
  metadata {
    name      = "fluentd-config"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "fluent.conf" = <<-EOT
      <source>
        @type tail
        path /var/log/containers/*.log
        pos_file /var/log/fluentd.pos
        tag kube.*
        format json
        read_from_head true
      </source>

      <filter kube.**>
        @type kubernetes_metadata
      </filter>

      <match kube.**>
        @type cloudwatch_logs
        auto_create_stream true
        log_group_name fluentd-logs
        region #{var.aws_region}
        log_stream_name #{hostname}
        include_time_key true
        time_format %Y-%m-%dT%H:%M:%S.%N%:z
      </match>
    EOT
  }
  depends_on = [module.eks]

}

resource "kubernetes_service_account" "fluentd" {
  provider = kubernetes.generated
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.logging.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluentd_irsa.arn
    }
  }
  depends_on = [module.eks]
}

resource "kubernetes_daemon_set" "fluentd" {
  provider = kubernetes.generated
  depends_on = [module.eks]
  metadata {
    name      = "fluentd"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels = { app = "fluentd" }
  }

  spec {
    selector {
      match_labels = { app = "fluentd" }
    }

    template {
      metadata {
        labels = { app = "fluentd" }
      }

      spec {
        service_account_name = kubernetes_service_account.fluentd.metadata[0].name

        toleration {
          operator = "Exists"
        }

        container {
          name  = "fluentd"
          image = "fluent/fluentd-kubernetes-daemonset:v1.15.0-debian-cloudwatch-1.0"

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }
          }

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluentd/etc"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluentd_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "prometheus_rule" {
  provider = kubernetes.generated

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "app-api-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = { role = "alert-rules" }
    }
    spec = {
      groups = [
        {
          name = "api.rules"
          rules = [
            {
              alert = "HighErrorRate"
              expr  = "sum(rate(http_requests_total{job=\"backend\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"backend\"}[5m])) > 0.05"
              for   = "5m"
              labels = { severity = "page" }
              annotations = {
                summary     = "High API error rate (backend)"
                description = "Error rate > 5% for backend service for more than 5 minutes."
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [module.eks]

}

# Grafana dashboard as ConfigMap picked up by sidecar
resource "kubernetes_config_map" "grafana_dashboard_red" {
  provider = kubernetes.generated
  metadata {
    name      = "grafana-dashboard-red"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "red-node-metrics.json" = <<-EOT
{
  "annotations": { "list": [] },
  "editable": true,
  "panels": [
    {
      "type": "graph",
      "title": "Requests per second (rate)",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{job=\\"backend\\"}[1m]))",
          "legendFormat": "rps"
        }
      ],
      "id": 1
    },
    {
      "type": "graph",
      "title": "5xx error rate (%)",
      "targets": [
        {
          "expr": "100 * (sum(rate(http_requests_total{job=\\"backend\\",status=~\\"5..\\"}[5m])) / sum(rate(http_requests_total{job=\\"backend\\"}[5m])))",
          "legendFormat": "error_percent"
        }
      ],
      "id": 2
    },
    {
      "type": "graph",
      "title": "P95 request duration (s)",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\\"backend\\"}[5m])) by (le))",
          "legendFormat": "p95"
        }
      ],
      "id": 3
    },
    {
      "type": "graph",
      "title": "Node CPU Utilization",
      "targets": [
        {
          "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\\"idle\\"}[5m])) * 100)",
          "legendFormat": "{{instance}}"
        }
      ],
      "id": 4
    },
    {
      "type": "graph",
      "title": "Node Memory Utilization",
      "targets": [
        {
          "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
          "legendFormat": "{{instance}}"
        }
      ],
      "id": 5
    }
  ],
  "schemaVersion": 16,
  "title": "App RED + Node Metrics",
  "version": 1
}
EOT
  }
  depends_on = [module.eks]
}
