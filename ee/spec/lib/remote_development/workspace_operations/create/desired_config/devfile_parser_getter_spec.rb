# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileParserGetter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:logger) { instance_double("RemoteDevelopment::Logger") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:labels) { { "some-label": "value", "other-label": "other-value" } }
  let(:agent_annotations) { { "some/annotation": "value" } }
  let(:workspace_name) { "workspace-name" }
  let(:workspace_namespace) { "workspace-namespace" }
  let(:context) do
    {
      processed_devfile_yaml: example_devfile_yaml,
      logger: logger,
      workspace_inventory_annotations_for_partial_reconciliation: { k1: "v1", k2: "v2" },
      domain_template: "domain_template",
      labels: labels,
      workspace_name: workspace_name,
      workspace_namespace: workspace_namespace,
      replicas: 1
    }
  end

  describe "#get" do
    subject(:result) { described_class.get(context) }

    context "when happy path" do
      # noinspection KubernetesNonEditableKeys -- This is the resource as returned by the devfile executable, we want
      #                                           to assert on exactly this YAML
      let(:expected_desired_config_yaml) do
        <<~YAML
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            annotations:
              k1: v1
              k2: v2
            labels:
              other-label: other-value
              some-label: value
            name: workspace-name
            namespace: workspace-namespace
          spec:
            replicas: 1
            selector:
              matchLabels:
                other-label: other-value
                some-label: value
            strategy:
              type: Recreate
            template:
              metadata:
                annotations:
                  k1: v1
                  k2: v2
                labels:
                  other-label: other-value
                  some-label: value
                name: workspace-name
                namespace: workspace-namespace
              spec:
                containers:
                - env:
                  - name: PROJECT_SOURCE
                    value: /projects
                  - name: PROJECTS_ROOT
                    value: /projects
                  image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
                  imagePullPolicy: Always
                  name: tooling-container
                  resources: {}
                - env:
                  - name: PROJECT_SOURCE
                    value: /projects
                  - name: PROJECTS_ROOT
                    value: /projects
                  - name: MYSQL_ROOT_PASSWORD
                    value: my-secret-pw
                  image: mysql
                  imagePullPolicy: Always
                  name: database-container
                  resources: {}
                - args:
                  - -n
                  - user-defined entrypoint command
                  command:
                  - echo
                  env:
                  - name: PROJECT_SOURCE
                    value: /projects
                  - name: PROJECTS_ROOT
                    value: /projects
                  image: quay.io/mloriedo/universal-developer-image:ubi8-dw-demo
                  imagePullPolicy: Always
                  name: user-defined-entrypoint-cmd-component
                  resources: {}
          status: {}
          ---
          apiVersion: v1
          kind: Service
          metadata:
            annotations:
              k1: v1
              k2: v2
            labels:
              other-label: other-value
              some-label: value
            name: workspace-name
            namespace: workspace-namespace
          spec:
            selector:
              other-label: other-value
              some-label: value
          status:
            loadBalancer: {}
        YAML
      end

      it "returns devfile contents" do
        expect(result).to include(:desired_config_yaml)
        expect(result[:desired_config_yaml]).not_to be_empty
        expect(result[:desired_config_yaml]).to eq(expected_desired_config_yaml)
      end
    end

    shared_examples "fails" do
      it "logs the error and raises the exception" do
        expect { result }.to raise_error(StandardError, exception_message)
        expect(logger).to have_received(:warn).with(
          message: error_message,
          error_type: "create_devfile_parser_error",
          workspace_name: workspace_name,
          workspace_namespace: workspace_namespace,
          devfile_parser_error: exception_message
        )
      end
    end

    context "when Devfile::Parser#get_all raises Devfile::CliError" do
      let(:exception_message) { "exception message" }
      let(:error_message) do
        <<~MSG.squish
          Devfile::CliError: A non zero return code was observed when invoking the devfile CLI
          executable from the devfile gem.
        MSG
      end

      before do
        allow(Devfile::Parser).to receive(:get_all).and_raise(Devfile::CliError.new(exception_message))
        allow(logger).to receive(:warn)
      end

      it_behaves_like "fails"
    end

    context "when Devfile::Parser#get_all raises StandardError" do
      let(:exception_message) { "exception message" }
      let(:error_message) do
        <<~MSG.squish
          StandardError: An unrecoverable error occurred when invoking the devfile gem,
          this may hint that a gem with a wrong architecture is being used.
        MSG
      end

      before do
        allow(Devfile::Parser).to receive(:get_all).and_raise(StandardError.new(exception_message))
        allow(logger).to receive(:warn)
      end

      it_behaves_like "fails"
    end
  end
end
