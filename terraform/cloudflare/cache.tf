# Cache rules of the zone. This resource owns the zone's WHOLE cache-settings phase: a cache rule added in
# the dashboard is removed on the next apply.
#
# APEX's web app (apex.<domain>): Caddy sends Cache-Control: no-cache on every file, because Flutter's
# files keep their names across builds. Without this rule Cloudflare's Browser Cache TTL (4 h) replaced it
# on .js files, so browsers kept running the previous release for hours after a deploy (2026-11-25).
resource "cloudflare_ruleset" "cache" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = "Cache rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules = [
    {
      description = "APEX web: browsers keep the origin's Cache-Control"
      expression  = "(http.host eq \"${local.apex_web_hostname}\")"
      action      = "set_cache_settings"
      action_parameters = {
        browser_ttl = {
          mode = "respect_origin"
        }
      }
      enabled = true
    },
  ]
}
