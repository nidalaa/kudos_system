MissionControl::Jobs.http_basic_auth_user     = ENV.fetch("JOBS_USERNAME", "admin")
MissionControl::Jobs.http_basic_auth_password = ENV.fetch("JOBS_PASSWORD", "changeme")
