# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::DeployDrivers::FlowDefinitionValidator, feature_category: :continuous_delivery do
  let(:driver) { Cd::DeployDrivers::Registry.find('argo-rollouts') }

  subject(:validator) { described_class.new(document: YAML.safe_load(definition), drivers: [driver]) }

  context 'when the embedded service and step configs match the driver schemas' do
    let(:definition) do
      <<~YAML
        environments:
          production:
            services:
              web:
                namespace: argocd
                application: web-production
                manifest_repository:
                  type: gitlab
                  host: https://gitlab.example.com
                  project: group/gitops
                  branch: main
                  manifests_path: manifests
        steps:
          - type: com.gitlab.cd.steps.stage
            name: canary
            steps:
              - type: com.gitlab.cd.argo.rolling.deploy
                environment: production
                services:
                  - name: web
      YAML
    end

    it 'is valid' do
      expect(validator).to be_valid
      expect(validator.errors).to be_empty
    end
  end

  context 'when several drivers are given and only one matches' do
    let(:non_matching_driver) do
      instance_double(Cd::DeployDrivers::Driver,
        steps_schema: { 'type' => 'object', 'required' => ['nonexistent'] },
        application_environment_schema: { 'type' => 'object', 'required' => ['nonexistent'] })
    end

    let(:definition) do
      <<~YAML
        environments:
          production:
            services:
              web:
                namespace: argocd
                application: web-production
                manifest_repository:
                  type: gitlab
                  host: https://gitlab.example.com
                  project: group/gitops
                  branch: main
                  manifests_path: manifests
        steps:
          - type: com.gitlab.cd.steps.stage
            name: production
            steps:
              - type: com.gitlab.cd.argo.rolling.deploy
                environment: production
                services:
                  - name: web
      YAML
    end

    subject(:validator) do
      described_class.new(document: YAML.safe_load(definition), drivers: [non_matching_driver, driver])
    end

    it 'is valid, because a driver-owned part only needs to match one driver in the list' do
      expect(validator).to be_valid
      expect(validator.errors).to be_empty
    end
  end

  context 'when several drivers are given and none match' do
    let(:other_non_matching_driver) do
      instance_double(Cd::DeployDrivers::Driver,
        steps_schema: { 'type' => 'object', 'required' => ['also_nonexistent'] },
        application_environment_schema: { 'type' => 'object', 'required' => ['also_nonexistent'] })
    end

    let(:non_matching_driver) do
      instance_double(Cd::DeployDrivers::Driver,
        steps_schema: { 'type' => 'object', 'required' => ['nonexistent'] },
        application_environment_schema: { 'type' => 'object', 'required' => ['nonexistent'] })
    end

    let(:definition) do
      <<~YAML
        environments:
          production:
            services:
              web:
                namespace: argocd
                application: web-production
                manifest_repository:
                  type: gitlab
                  host: https://gitlab.example.com
                  project: group/gitops
                  branch: main
                  manifests_path: manifests
        steps:
          - type: com.gitlab.cd.steps.stage
            name: production
            steps:
              - type: com.gitlab.cd.argo.rolling.deploy
                environment: production
                services:
                  - name: web
      YAML
    end

    subject(:validator) do
      described_class.new(
        document: YAML.safe_load(definition), drivers: [non_matching_driver, other_non_matching_driver]
      )
    end

    it 'is invalid, reporting the errors from the first driver in the list', :aggregate_failures do
      expect(validator).not_to be_valid
      expect(validator.errors).to include(a_string_matching(/missing required properties.*nonexistent/))
    end
  end

  context 'when no drivers are registered' do
    let(:definition) do
      <<~YAML
        steps:
          - type: com.gitlab.cd.steps.stage
            name: production
            steps:
              - type: com.gitlab.cd.argo.rolling.deploy
                environment: production
      YAML
    end

    subject(:validator) { described_class.new(document: YAML.safe_load(definition), drivers: []) }

    it 'is valid, rather than raising, since there is no driver schema to check the step against' do
      expect(validator).to be_valid
      expect(validator.errors).to be_empty
    end
  end

  context 'when a service config is missing required driver schema properties' do
    let(:definition) do
      <<~YAML
        environments:
          production:
            services:
              web:
                namespace: argocd
        steps:
          - type: com.gitlab.cd.steps.wait
            seconds: 0
      YAML
    end

    it 'is invalid' do
      expect(validator).not_to be_valid
      expect(validator.errors).to include(
        a_string_matching(/production.*service 'web'.*missing required properties/)
      )
    end
  end

  context 'when a step does not match the driver steps schema' do
    let(:definition) do
      <<~YAML
        environments: {}
        steps:
          - type: com.gitlab.cd.steps.stage
            name: canary
            steps:
              - type: com.gitlab.cd.argo.rolling.deploy
                environment: production
      YAML
    end

    it 'is invalid', :aggregate_failures do
      expect(validator).not_to be_valid
      expect(validator.errors).to include(
        a_string_matching(/step targeting environment 'production'.*missing required properties/)
      )
    end
  end

  # Absent from every driver's steps schema, so they must be excluded from that check.
  context 'when the flow contains steps the orchestration engine owns' do
    let(:definition) do
      <<~YAML
        steps:
          - type: com.gitlab.cd.steps.wait
            seconds: 30
          - type: com.gitlab.cd.steps.stage
            name: soak
            steps:
              - type: com.gitlab.cd.steps.wait
                seconds: 60
      YAML
    end

    it 'is valid', :aggregate_failures do
      expect(validator).to be_valid
      expect(validator.errors).to be_empty
    end
  end

  context 'when the document does not match the orchestration engine schema' do
    context 'when the flow still uses the pre-0.4.0 top-level stages list' do
      let(:definition) do
        <<~YAML
          environments: {}
          stages:
            - name: canary
              steps:
                - type: com.gitlab.cd.argo.rolling.deploy
                  environment: production
        YAML
      end

      it 'is invalid, naming the document rather than a step', :aggregate_failures do
        expect(validator).not_to be_valid
        expect(validator.errors).to include(a_string_matching(/^flow definition: /))
      end
    end

    context 'when steps is empty' do
      let(:definition) { "steps: []\n" }

      it 'is invalid' do
        expect(validator).not_to be_valid
      end
    end

    context 'when a driver step is also invalid' do
      let(:definition) do
        <<~YAML
          stages:
            - name: canary
              steps:
                - type: com.gitlab.cd.argo.rolling.deploy
        YAML
      end

      it 'reports only the document errors' do
        expect(validator.errors).to all(start_with('flow definition: '))
      end
    end
  end

  # Parsing the definition YAML is the caller's concern (see Cd::ApplicationFlowDefinition),
  # so this validator only ever sees an already-parsed document.
  context 'when the document does not parse to a mapping' do
    context 'when nil' do
      let(:definition) { '' }

      it 'is valid (there is nothing to check)' do
        expect(validator).to be_valid
      end
    end

    context 'when it parses to an array' do
      let(:definition) { "- production\n- staging\n" }

      it 'is invalid, because a flow definition is a document', :aggregate_failures do
        expect(validator).not_to be_valid
        expect(validator.errors).to include(a_string_matching(/^flow definition: /))
      end
    end
  end
end
