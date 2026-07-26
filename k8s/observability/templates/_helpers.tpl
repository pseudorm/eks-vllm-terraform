# templates/_helpers.tpl
{{- define "observability.nodeSelector" -}}
internal: "true"
compute: "cpu"
processor: "amd64"
workload: "general-purpose"
{{- end }}
