# frozen_string_literal: true

require "fast_spec_helper"
# NOTE This explicit "hashdiff" require exists so we can run this spec against historical SHAs, before the require
# existed in ee/spec/fast_spec_helper.rb. It can be removed once there is no longer a need to run it against
# historical SHAs.
require "hashdiff"

# noinspection RubyLiteralArrayInspection -- Keep original formatting for readability
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main, "Integration test for main", feature_category: :workspaces do
  include_context "with constant modules"

  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version of these models, so we can use fast_spec_helper.
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:agent) { instance_double("Clusters::Agent", id: 991) }

  let(:workspace_variable_environment) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "ENV_VAR1",
      value: "env-var-value1"
    )
  end

  let(:workspace_variable_file) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "FILE_VAR1",
      value: "file-var-value1"
    )
  end

  # rubocop:disable RSpec/VerifiedDoubles -- This is a scope which is of type ActiveRecord::Associations::CollectionProxy, it can't be a verified double
  let(:workspace_variables) do
    double(
      :workspace_variables,
      with_variable_type_environment: [workspace_variable_environment],
      with_variable_type_file: [workspace_variable_file]
    )
  end
  # rubocop:enable RSpec/VerifiedDoubles

  let(:image_pull_secret_stringified) { { "name" => "registry-secret", "namespace" => "default" } }
  let(:image_pull_secret_symbolized) { { name: "registry-secret", namespace: "default" } }
  let(:image_pull_secret) { image_pull_secret_stringified }
  let(:shared_namespace) { "" }
  let(:use_kubernetes_user_namespaces) { false }
  let(:workspace_namespace) { "gl-rd-ns-991-990-fedcba" }

  let(:workspaces_agent_config) do
    instance_double(
      "RemoteDevelopment::WorkspacesAgentConfig",
      allow_privilege_escalation: false,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: "standard",
      default_resources_per_workspace_container:
        { requests: { cpu: "0.5", memory: "512Mi" }, limits: { cpu: "1", memory: "1Gi" } },
      # NOTE: This input version of max_resources_per_workspace is deeply UNSORTED, to verify the legacy behavior
      # that the "workspaces.gitlab.com/max-resources-per-workspace-sha256" annotation should be calculated
      # from the OpenSSL::Digest::SHA256.hexdigest of the #to_s of the SHALLOW sorted version of the hash. In other
      # words, the hash is calculated with limits and requests in alphabetical order, but not memory and cpu.
      max_resources_per_workspace: { requests: { memory: "1Gi", cpu: "1" }, limits: { memory: "4Gi", cpu: "2" } },
      annotations: { environment: "production", team: "engineering" },
      labels: { app: "workspace", tier: "development" },
      image_pull_secrets: [image_pull_secret],
      network_policy_enabled: true,
      network_policy_egress: [
        {
          allow: "0.0.0.0/0",
          except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
        }
      ],
      gitlab_workspaces_proxy_http_enabled: true,
      gitlab_workspaces_proxy_namespace: "gitlab-workspaces",
      gitlab_workspaces_proxy_ssh_enabled: true,
      dns_zone: "workspaces.localdev.me",
      shared_namespace: shared_namespace
    )
  end

  let(:project) { instance_double("Project", path: "test-project") }

  let(:input_processed_devfile_yaml) { input_processed_devfile_yaml_with_poststart_event }

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      id: 993,
      agent: agent,
      workspaces_agent_config: workspaces_agent_config,
      name: "workspace-991-990-fedcba",
      namespace: workspace_namespace,
      desired_state_running?: desired_state_running,
      actual_state: states_module::RUNNING,
      workspace_variables: workspace_variables,
      project: project,
      processed_devfile: input_processed_devfile_yaml
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  subject(:context) do
    # noinspection RubyMismatchedArgumentType -- We are intentionally passing a double for Workspace
    described_class.main(
      params: {
        agent: agent
      },
      workspace: workspace,
      logger: logger
    )
  end

  shared_examples "generated desired_config checks" do
    it "exactly matches the generated desired_config", :unlimited_max_formatted_output_length do
      actual_desired_config = context[:desired_config]
      expect(actual_desired_config).to be_a(::RemoteDevelopment::WorkspaceOperations::DesiredConfig)
      expect(actual_desired_config).to be_valid

      actual_desired_config_array =
        actual_desired_config
          .attributes
          .fetch("desired_config_array")
          .map(&:deep_symbolize_keys)

      expected_desired_config_array_sorted = expected_desired_config_array.map(&:deep_symbolize_keys)

      # compare the names and kinds of the resources
      expect(actual_desired_config_array.map { |c| [c.fetch(:kind), c.fetch(:metadata).fetch(:name)] })
        .to eq(expected_desired_config_array_sorted.map { |c| [c.fetch(:kind), c.fetch(:metadata).fetch(:name)] })

      differences = {}

      # Use Hashdiff on each element to give a more concise and readable diff
      actual_desired_config_array.each_with_index do |resource, index|
        # NOTE: The order of the diff is expected value first, actual value second. This matches the
        #       "expected ..., got ..." order which RSpec uses by default.
        resource_differences = Hashdiff.diff(expected_desired_config_array_sorted[index], resource, use_lcs: false)

        next unless resource_differences.present?

        key = "index=#{index}, kind='#{resource.fetch(:kind)}', name='#{resource.fetch(:metadata).fetch(:name)}'"
        value = resource_differences.map(&:inspect).join("\n").to_s
        differences[key] = value
      end

      expect(differences)
        .to be_empty, differences.map { |k, v| "Differences found in resource at #{k} \n#{v}" }.join("\n\n").to_s
    end
  end

  context "when desired_state is stopped" do
    let(:desired_state_running) { false }
    let(:expected_desired_config_array) { expected_desired_config_array_with_desired_state_stopped }

    it_behaves_like "generated desired_config checks"

    context "with shared namespace set" do
      let(:shared_namespace) { "default" }
      let(:workspace_namespace) { shared_namespace }
      let(:expected_desired_config_array) do
        expected_desired_config_array_for_shared_namespace_with_desired_state_stopped
      end

      it_behaves_like "generated desired_config checks"
    end
  end

  context "when desired_state is running" do
    let(:desired_state_running) { true }
    let(:expected_desired_config_array) { expected_desired_config_array_with_desired_state_running }

    it_behaves_like "generated desired_config checks"

    context "with legacy devfile that includes postStart event" do
      let(:input_processed_devfile_yaml) { input_processed_devfile_yaml_with_legacy_poststart_event }
      let(:expected_desired_config_array) do
        expected_desired_config_array_from_legacy_devfile_with_poststart_and_with_desired_state_running
      end

      it_behaves_like "generated desired_config checks"
    end

    context "with legacy devfile that does not include postStart event" do
      let(:input_processed_devfile_yaml) { input_processed_devfile_yaml_without_poststart_event }
      let(:expected_desired_config_array) do
        expected_desired_config_array_from_legacy_devfile_with_no_poststart_and_with_desired_state_running
      end

      it_behaves_like "generated desired_config checks"
    end

    context "with shared namespace set" do
      let(:shared_namespace) { "default" }
      let(:workspace_namespace) { shared_namespace }
      let(:expected_desired_config_array) do
        expected_desired_config_array_for_shared_namespace_with_desired_state_running
      end

      it_behaves_like "generated desired_config checks"
    end

    context "with use_kubernetes_user_namespaces set" do
      let(:use_kubernetes_user_namespaces) { true }
      let(:expected_desired_config_array) do
        expected_desired_config_array_with_desired_state_running_with_use_kubernetes_user_namespaces_set
      end

      it_behaves_like "generated desired_config checks"
    end
  end

  # @return [String]
  def input_processed_devfile_yaml_with_poststart_event
    <<~YAML
      ---
      schemaVersion: 2.2.0
      metadata: {}
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
            args:
              - "echo 'tooling container args'"
            command:
              - "/bin/sh"
              - "-c"
            volumeMounts:
              - name: gl-workspace-data
                path: /projects
            env:
              - name: GL_ENV_NAME
                value: "gl-env-value"
            endpoints:
              - name: server
                targetPort: 60001
                exposure: public
                secure: true
                protocol: https
            dedicatedPod: false
            mountSources: true
        - name: sidecar-container
          container:
            image: "sidecar-container:latest"
            volumeMounts:
              - name: gl-workspace-data
                path: "/projects"
            env:
              - name: GL_ENV2_NAME
                value: "gl-env2-value"
            args:
              - "echo 'sidecar container args'"
            command:
              - "/bin/sh"
              - "-c"
            memoryLimit: 1000Mi
            memoryRequest: 500Mi
            cpuLimit: 500m
            cpuRequest: 100m
        - name: gl-workspace-data
          volume:
            size: 50Gi
      commands:
        - id: gl-internal-example-command-1
          exec:
            commandLine: "echo 'gl-internal-example-command-1'"
            component: tooling-container
            label: gl-internal-blocking
            workingDir: /projects
        - id: gl-internal-example-command-2
          exec:
            commandLine: "echo 'gl-internal-example-command-2'"
            component: tooling-container
            label: gl-internal
            workingDir: /projects
        - id: example-prestart-apply-command
          apply:
            component: sidecar-container
      events:
        preStart:
          - example-prestart-apply-command
        postStart:
          - gl-internal-example-command-1
          - gl-internal-example-command-2
      variables: {}
    YAML
  end

  # @return [String]
  def input_processed_devfile_yaml_with_legacy_poststart_event
    <<~YAML
      ---
      schemaVersion: 2.2.0
      metadata: {}
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
            args:
              - "echo 'tooling container args'"
            command:
              - "/bin/sh"
              - "-c"
            volumeMounts:
              - name: gl-workspace-data
                path: /projects
            env:
              - name: GL_ENV_NAME
                value: "gl-env-value"
            endpoints:
              - name: server
                targetPort: 60001
                exposure: public
                secure: true
                protocol: https
            dedicatedPod: false
            mountSources: true
        - name: sidecar-container
          container:
            image: "sidecar-container:latest"
            volumeMounts:
              - name: gl-workspace-data
                path: "/projects"
            env:
              - name: GL_ENV2_NAME
                value: "gl-env2-value"
            args:
              - "echo 'sidecar container args'"
            command:
              - "/bin/sh"
              - "-c"
            memoryLimit: 1000Mi
            memoryRequest: 500Mi
            cpuLimit: 500m
            cpuRequest: 100m
        - name: gl-workspace-data
          volume:
            size: 50Gi
      commands:
        - id: gl-internal-example-command-1
          exec:
            commandLine: "echo 'gl-internal-example-command-1'"
            component: tooling-container
        - id: gl-internal-example-command-2
          exec:
            commandLine: "echo 'gl-internal-example-command-2'"
            component: tooling-container
        - id: example-prestart-apply-command
          apply:
            component: sidecar-container
      events:
        preStart:
          - example-prestart-apply-command
        postStart:
          - gl-internal-example-command-1
          - gl-internal-example-command-2
      variables: {}
    YAML
  end

  # @return [String]
  def input_processed_devfile_yaml_without_poststart_event
    <<~YAML
      ---
      schemaVersion: 2.2.0
      metadata: {}
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
            args:
              - "echo 'tooling container args'"
            command:
              - "/bin/sh"
              - "-c"
            volumeMounts:
              - name: gl-workspace-data
                path: /projects
            env:
              - name: GL_ENV_NAME
                value: "gl-env-value"
            endpoints:
              - name: server
                targetPort: 60001
                exposure: public
                secure: true
                protocol: https
            dedicatedPod: false
            mountSources: true
        - name: gl-project-cloner
          container:
            image: alpine/git:2.45.2
            volumeMounts:
              - name: gl-workspace-data
                path: "/projects"
            args:
              - "echo 'project cloner container args'"
            command:
              - "/bin/sh"
              - "-c"
            memoryLimit: 1000Mi
            memoryRequest: 500Mi
            cpuLimit: 500m
            cpuRequest: 100m
        - name: gl-workspace-data
          volume:
            size: 50Gi
      commands:
        - id: gl-project-cloner-command
          apply:
            component: gl-project-cloner
      events:
        preStart:
          - gl-project-cloner-command
      variables: {}
    YAML
  end

  # rubocop:disable Layout/LineLength, Style/WordArray -- Keep original formatting for readability
  # noinspection RubyLiteralArrayInspection
  # @return [Array]
  def expected_desired_config_array_with_desired_state_running
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\ncomponent_name=\"tooling-container\"\nmain_component_name=\"tooling-container\"\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}/${component_name}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running poststart commands for workspace...\"\n}>> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\nif [ \"${component_name}\" = \"${main_component_name}\" ]; then\n  {\n    echo \"$(date -Iseconds): ----------------------------------------\"\n    echo \"$(date -Iseconds): Running internal blocking poststart commands script...\"\n  } >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n  \"/workspace-scripts/tooling-container/gl-run-internal-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\"\nfi\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running non-blocking poststart commands script...\"\n} >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\"/workspace-scripts/tooling-container/gl-run-non-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\" &\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap",
                            items: [
                              {
                                key: "gl-internal-example-command-1",
                                path: "tooling-container/gl-internal-example-command-1"
                              },
                              {
                                key: "gl-internal-example-command-2",
                                path: "tooling-container/gl-internal-example-command-2"
                              },
                              {
                                key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                              },
                              {
                                key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        data: {
          "tooling-container-gl-run-internal-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-1...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-1) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-1.\"\n",
          "tooling-container-gl-run-non-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-2...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-2) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # noinspection RubyLiteralArrayInspection
  # @return [Array]
  def expected_desired_config_array_with_desired_state_running_with_use_kubernetes_user_namespaces_set
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\ncomponent_name=\"tooling-container\"\nmain_component_name=\"tooling-container\"\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}/${component_name}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running poststart commands for workspace...\"\n}>> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\nif [ \"${component_name}\" = \"${main_component_name}\" ]; then\n  {\n    echo \"$(date -Iseconds): ----------------------------------------\"\n    echo \"$(date -Iseconds): Running internal blocking poststart commands script...\"\n  } >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n  \"/workspace-scripts/tooling-container/gl-run-internal-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\"\nfi\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running non-blocking poststart commands script...\"\n} >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\"/workspace-scripts/tooling-container/gl-run-non-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\" &\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                hostUsers: false,
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap",
                            items: [
                              {
                                key: "gl-internal-example-command-1",
                                path: "tooling-container/gl-internal-example-command-1"
                              },
                              {
                                key: "gl-internal-example-command-2",
                                path: "tooling-container/gl-internal-example-command-2"
                              },
                              {
                                key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                              },
                              {
                                key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        data: {
          "tooling-container-gl-run-internal-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-1...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-1) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-1.\"\n",
          "tooling-container-gl-run-non-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-2...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-2) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def expected_desired_config_array_with_desired_state_stopped
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 0,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\ncomponent_name=\"tooling-container\"\nmain_component_name=\"tooling-container\"\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}/${component_name}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running poststart commands for workspace...\"\n}>> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\nif [ \"${component_name}\" = \"${main_component_name}\" ]; then\n  {\n    echo \"$(date -Iseconds): ----------------------------------------\"\n    echo \"$(date -Iseconds): Running internal blocking poststart commands script...\"\n  } >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n  \"/workspace-scripts/tooling-container/gl-run-internal-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\"\nfi\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running non-blocking poststart commands script...\"\n} >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\"/workspace-scripts/tooling-container/gl-run-non-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\" &\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap",
                            items: [
                              {
                                key: "gl-internal-example-command-1",
                                path: "tooling-container/gl-internal-example-command-1"
                              },
                              {
                                key: "gl-internal-example-command-2",
                                path: "tooling-container/gl-internal-example-command-2"
                              },
                              {
                                key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                              },
                              {
                                key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        data: {
          "tooling-container-gl-run-internal-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-1...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-1) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-1.\"\n",
          "tooling-container-gl-run-non-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-2...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-2) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def expected_desired_config_array_from_legacy_devfile_with_poststart_and_with_desired_state_running
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\"/workspace-scripts/gl-run-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/poststart-stderr.log\"\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        data: {
          "gl-run-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/gl-internal-example-command-1...\"\n/workspace-scripts/gl-internal-example-command-1 || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/gl-internal-example-command-1.\"\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/gl-internal-example-command-2...\"\n/workspace-scripts/gl-internal-example-command-2 || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def expected_desired_config_array_from_legacy_devfile_with_no_poststart_and_with_desired_state_running
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991"
              },
              name: "workspace-991-990-fedcba",
              namespace: "gl-rd-ns-991-990-fedcba"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'project cloner container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "alpine/git:2.45.2",
                    imagePullPolicy: "Always",
                    name: "gl-project-cloner-gl-project-cloner-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {},
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        kind: "ResourceQuota",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba",
          namespace: "gl-rd-ns-991-990-fedcba"
        },
        spec: {
          hard: {
            "limits.cpu": "2",
            "limits.memory": "4Gi",
            "requests.cpu": "1",
            "requests.memory": "1Gi"
          }
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "gl-rd-ns-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def expected_desired_config_array_for_shared_namespace_with_desired_state_running
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "default"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991",
              "workspaces.gitlab.com/id": "993"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991",
                "workspaces.gitlab.com/id": "993"
              },
              name: "workspace-991-990-fedcba",
              namespace: "default"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\ncomponent_name=\"tooling-container\"\nmain_component_name=\"tooling-container\"\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}/${component_name}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running poststart commands for workspace...\"\n}>> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\nif [ \"${component_name}\" = \"${main_component_name}\" ]; then\n  {\n    echo \"$(date -Iseconds): ----------------------------------------\"\n    echo \"$(date -Iseconds): Running internal blocking poststart commands script...\"\n  } >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n  \"/workspace-scripts/tooling-container/gl-run-internal-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\"\nfi\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running non-blocking poststart commands script...\"\n} >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\"/workspace-scripts/tooling-container/gl-run-non-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\" &\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap",
                            items: [
                              {
                                key: "gl-internal-example-command-1",
                                path: "tooling-container/gl-internal-example-command-1"
                              },
                              {
                                key: "gl-internal-example-command-2",
                                path: "tooling-container/gl-internal-example-command-2"
                              },
                              {
                                key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                              },
                              {
                                key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "default"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {
            matchLabels: {
              "workspaces.gitlab.com/id": "993"
            }
          },
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "default"
        },
        data: {
          "tooling-container-gl-run-internal-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-1...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-1) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-1.\"\n",
          "tooling-container-gl-run-non-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-2...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-2) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "default"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "default"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "default"
        }
      }
    ]
  end

  # @return [Array]
  def expected_desired_config_array_for_shared_namespace_with_desired_state_stopped
    [
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-workspace-inventory",
          namespace: "default"
        }
      },
      {
        apiVersion: "apps/v1",
        kind: "Deployment",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          replicas: 0,
          selector: {
            matchLabels: {
              app: "workspace",
              tier: "development",
              "agent.gitlab.com/id": "991",
              "workspaces.gitlab.com/id": "993"
            }
          },
          strategy: {
            type: "Recreate"
          },
          template: {
            metadata: {
              annotations: {
                environment: "production",
                team: "engineering",
                "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
                "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
                "workspaces.gitlab.com/id": "993",
                "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
                "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
              },
              labels: {
                app: "workspace",
                tier: "development",
                "agent.gitlab.com/id": "991",
                "workspaces.gitlab.com/id": "993"
              },
              name: "workspace-991-990-fedcba",
              namespace: "default"
            },
            spec:
              {
                containers: [
                  {
                    args: [
                      "echo 'tooling container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV_NAME",
                        value: "gl-env-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                    imagePullPolicy: "Always",
                    name: "tooling-container",
                    ports: [
                      {
                        containerPort: 60001,
                        name: "server",
                        protocol: "TCP"
                      }
                    ],
                    resources: {
                      limits: {
                        cpu: "1",
                        memory: "1Gi"
                      },
                      requests: {
                        cpu: "0.5",
                        memory: "512Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      },
                      {
                        name: "gl-workspace-scripts",
                        mountPath: "/workspace-scripts"
                      }
                    ],
                    lifecycle: {
                      postStart: {
                        exec: {
                          command: [
                            "/bin/sh",
                            "-c",
                            "#!/bin/sh\n\ncomponent_name=\"tooling-container\"\nmain_component_name=\"tooling-container\"\n\nmkdir -p \"${GL_WORKSPACE_LOGS_DIR}/${component_name}\"\nln -sf \"${GL_WORKSPACE_LOGS_DIR}\" /tmp\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running poststart commands for workspace...\"\n}>> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\nif [ \"${component_name}\" = \"${main_component_name}\" ]; then\n  {\n    echo \"$(date -Iseconds): ----------------------------------------\"\n    echo \"$(date -Iseconds): Running internal blocking poststart commands script...\"\n  } >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n  \"/workspace-scripts/tooling-container/gl-run-internal-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\"\nfi\n\n{\n  echo \"$(date -Iseconds): ----------------------------------------\"\n  echo \"$(date -Iseconds): Running non-blocking poststart commands script...\"\n} >> \"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\"\n\n\"/workspace-scripts/tooling-container/gl-run-non-blocking-poststart-commands.sh\" 1>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stdout.log\" 2>>\"${GL_WORKSPACE_LOGS_DIR}/${component_name}/poststart-stderr.log\" &\n"
                          ]
                        }
                      }
                    }
                  }
                ],
                initContainers: [
                  {
                    args: [
                      "echo 'sidecar container args'"
                    ],
                    command: [
                      "/bin/sh",
                      "-c"
                    ],
                    env: [
                      {
                        name: "PROJECT_SOURCE",
                        value: "/projects"
                      },
                      {
                        name: "PROJECTS_ROOT",
                        value: "/projects"
                      },
                      {
                        name: "GL_ENV2_NAME",
                        value: "gl-env2-value"
                      }
                    ],
                    envFrom: [
                      {
                        secretRef: {
                          name: "workspace-991-990-fedcba-env-var"
                        }
                      }
                    ],
                    image: "sidecar-container:latest",
                    imagePullPolicy: "Always",
                    name: "sidecar-container-example-prestart-apply-command-1",
                    resources: {
                      limits: {
                        cpu: "500m",
                        memory: "1000Mi"
                      },
                      requests: {
                        cpu: "100m",
                        memory: "500Mi"
                      }
                    },
                    securityContext: {
                      allowPrivilegeEscalation: false,
                      privileged: false,
                      runAsNonRoot: true,
                      runAsUser: 5001
                    },
                    volumeMounts: [
                      {
                        mountPath: "/projects",
                        name: "gl-workspace-data"
                      },
                      {
                        mountPath: "/.workspace-data/variables/file",
                        name: "gl-workspace-variables"
                      }
                    ]
                  }
                ],
                runtimeClassName: "standard",
                securityContext: {
                  fsGroup: 0,
                  fsGroupChangePolicy: "OnRootMismatch",
                  runAsNonRoot: true,
                  runAsUser: 5001
                },
                serviceAccountName: "workspace-991-990-fedcba",
                volumes: [
                  {
                    name: "gl-workspace-data",
                    persistentVolumeClaim: {
                      claimName: "workspace-991-990-fedcba-gl-workspace-data"
                    }
                  },
                  {
                    name: "gl-workspace-variables",
                    projected: {
                      defaultMode: 0o774,
                      sources: [
                        {
                          secret: {
                            name: "workspace-991-990-fedcba-file"
                          }
                        }
                      ]
                    }
                  },
                  {
                    name: "gl-workspace-scripts",
                    projected: {
                      defaultMode: 0o555,
                      sources: [
                        {
                          configMap: {
                            name: "workspace-991-990-fedcba-scripts-configmap",
                            items: [
                              {
                                key: "gl-internal-example-command-1",
                                path: "tooling-container/gl-internal-example-command-1"
                              },
                              {
                                key: "gl-internal-example-command-2",
                                path: "tooling-container/gl-internal-example-command-2"
                              },
                              {
                                key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                              },
                              {
                                key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                                path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        kind: "Service",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          ports: [
            {
              name: "server",
              port: 60001,
              targetPort: 60001
            }
          ],
          selector: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          }
        },
        status: {
          loadBalancer: {}
        }
      },
      {
        apiVersion: "v1",
        kind: "PersistentVolumeClaim",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-gl-workspace-data",
          namespace: "default"
        },
        spec: {
          accessModes: [
            "ReadWriteOnce"
          ],
          resources: {
            requests: {
              storage: "50Gi"
            }
          }
        },
        status: {}
      },
      {
        apiVersion: "v1",
        automountServiceAccountToken: false,
        imagePullSecrets: [
          {
            name: "registry-secret"
          }
        ],
        kind: "ServiceAccount",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        }
      },
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba",
          namespace: "default"
        },
        spec: {
          egress: [
            {
              ports: [
                {
                  port: 53,
                  protocol: "TCP"
                },
                {
                  port: 53,
                  protocol: "UDP"
                }
              ],
              to: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "kube-system"
                    }
                  }
                }
              ]
            },
            {
              to: [
                {
                  ipBlock: {
                    cidr: "0.0.0.0/0",
                    except: [
                      "10.0.0.0/8",
                      "172.16.0.0/12",
                      "192.168.0.0/16"
                    ]
                  }
                }
              ]
            }
          ],
          ingress: [
            {
              from: [
                {
                  namespaceSelector: {
                    matchLabels: {
                      "kubernetes.io/metadata.name": "gitlab-workspaces"
                    }
                  },
                  podSelector: {
                    matchLabels: {
                      "app.kubernetes.io/name": "gitlab-workspaces-proxy"
                    }
                  }
                }
              ]
            }
          ],
          podSelector: {
            matchLabels: {
              "workspaces.gitlab.com/id": "993"
            }
          },
          policyTypes: [
            "Ingress",
            "Egress"
          ]
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-workspace-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc",
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-scripts-configmap",
          namespace: "default"
        },
        data: {
          "tooling-container-gl-run-internal-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-1...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-1) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-1.\"\n",
          "tooling-container-gl-run-non-blocking-poststart-commands.sh": "#!/bin/sh\necho \"$(date -Iseconds): ----------------------------------------\"\necho \"$(date -Iseconds): Running /workspace-scripts/tooling-container/gl-internal-example-command-2...\"\n(cd /projects && /workspace-scripts/tooling-container/gl-internal-example-command-2) || true\necho \"$(date -Iseconds): Finished running /workspace-scripts/tooling-container/gl-internal-example-command-2.\"\n",
          "gl-internal-example-command-1": "echo 'gl-internal-example-command-1'",
          "gl-internal-example-command-2": "echo 'gl-internal-example-command-2'"
        }
      },
      {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "cli-utils.sigs.k8s.io/inventory-id": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-secrets-inventory",
          namespace: "default"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-env-var",
          namespace: "default"
        }
      },
      {
        apiVersion: "v1",
        data: {},
        kind: "Secret",
        metadata: {
          annotations: {
            environment: "production",
            team: "engineering",
            "config.k8s.io/owning-inventory": "workspace-991-990-fedcba-secrets-inventory",
            "workspaces.gitlab.com/host-template": "{{.port}}-workspace-991-990-fedcba.workspaces.localdev.me",
            "workspaces.gitlab.com/id": "993",
            "workspaces.gitlab.com/max-resources-per-workspace-sha256": "80d9131fadc41e0045b4d1b3180fb860e77845ab6df2ccb6859479a1ecb322fc"
          },
          labels: {
            app: "workspace",
            tier: "development",
            "agent.gitlab.com/id": "991",
            "workspaces.gitlab.com/id": "993"
          },
          name: "workspace-991-990-fedcba-file",
          namespace: "default"
        }
      }
    ]
  end

  # rubocop:enable Layout/LineLength, Style/WordArray
end
