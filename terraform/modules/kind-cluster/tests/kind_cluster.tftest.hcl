# Unit tests: run with `terraform test` — no Docker or real cluster required.
mock_provider "kind" {}

variables {
  name = "unit"
}

run "defaults_create_control_plane_plus_two_workers" {
  command = plan

  assert {
    condition     = length(kind_cluster.this.kind_config[0].node) == 3
    error_message = "Expected 1 control-plane + 2 workers by default."
  }

  assert {
    condition     = kind_cluster.this.kind_config[0].node[0].role == "control-plane"
    error_message = "First node must be the control plane."
  }

  assert {
    condition     = output.context == "kind-unit"
    error_message = "Context must follow kind's kind-<name> convention."
  }
}

run "port_mappings_land_on_control_plane" {
  command = plan

  variables {
    worker_count = 0
    port_mappings = [
      { container_port = 30300, host_port = 3000 },
      { container_port = 30900, host_port = 9090 },
    ]
  }

  assert {
    condition     = length(kind_cluster.this.kind_config[0].node[0].extra_port_mappings) == 2
    error_message = "Both port mappings should be attached to the control-plane node."
  }

  assert {
    condition     = kind_cluster.this.kind_config[0].node[0].extra_port_mappings[0].listen_address == "127.0.0.1"
    error_message = "Port mappings must bind to localhost by default."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Not_Valid"
  }

  expect_failures = [var.name]
}

run "rejects_port_outside_nodeport_range" {
  command = plan

  variables {
    port_mappings = [{ container_port = 8080, host_port = 8080 }]
  }

  expect_failures = [var.port_mappings]
}
