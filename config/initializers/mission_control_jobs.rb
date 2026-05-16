MissionControl::Jobs.authentication = ->(controller) {
  controller.http_basic_authenticate_or_request_with(
    name:     ENV.fetch("JOBS_USERNAME", "admin"),
    password: ENV.fetch("JOBS_PASSWORD", "changeme")
  )
}
