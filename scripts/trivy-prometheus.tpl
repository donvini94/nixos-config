{{- $engine := env "SCAN_ENGINE" -}}
{{- $image := env "SCAN_IMAGE_LABEL" -}}
{{- $critical := 0 -}}
{{- $high := 0 -}}
{{- range . -}}
{{- range .Vulnerabilities -}}
{{- if eq .Severity "CRITICAL" -}}{{- $critical = add1 $critical -}}{{- end -}}
{{- if eq .Severity "HIGH" -}}{{- $high = add1 $high -}}{{- end -}}
{{- end -}}
{{- end -}}
security_container_image_scan_success{engine="{{ $engine }}",image={{ $image }}} 1
security_container_image_vulnerabilities{engine="{{ $engine }}",image={{ $image }},severity="critical"} {{ $critical }}
security_container_image_vulnerabilities{engine="{{ $engine }}",image={{ $image }},severity="high"} {{ $high }}
