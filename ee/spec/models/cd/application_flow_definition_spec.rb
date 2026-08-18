# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationFlowDefinition, feature_category: :continuous_delivery do
  let_it_be(:application) { create(:cd_application) }

  describe 'associations' do
    it { is_expected.to belong_to(:application).required }
  end

  describe 'sharding key' do
    subject { build(:cd_application_flow_definition, application: application) }

    it { is_expected.to populate_sharding_key(:organization_id).with(application.organization_id) }
  end

  describe 'definition storage' do
    it 'persists the definition in object storage and reads it back' do
      content = "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 3\n"

      flow_definition = create(:cd_application_flow_definition, application: application, definition: content)

      expect(flow_definition.file_store).to eq(ObjectStorage::Store::LOCAL)
      expect(flow_definition.file.filename).to eq('definition.yml')
      expect(flow_definition.reload.definition).to eq(content)
    end
  end

  describe 'validations' do
    subject(:flow_definition) { build(:cd_application_flow_definition, application: application) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:definition) }
    it { is_expected.to validate_length_of(:definition).is_at_most(1.megabyte) }

    describe 'version' do
      before do
        allow(flow_definition).to receive(:assign_next_version)
      end

      it { is_expected.to validate_numericality_of(:version).only_integer.is_greater_than(0) }

      it 'enforces uniqueness of version scoped to application_id' do
        existing = create(:cd_application_flow_definition, application: application)

        duplicate = build(:cd_application_flow_definition, application: application)
        allow(duplicate).to receive(:assign_next_version)
        duplicate.version = existing.version

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:version]).to include('has already been taken')
      end
    end

    describe 'application organization' do
      it 'is invalid when the application belongs to a different organization' do
        other_organization = create(:organization)

        flow_definition = build(:cd_application_flow_definition, application: application,
          organization_id: other_organization.id)

        expect(flow_definition).not_to be_valid
        expect(flow_definition.errors[:application]).to include('must belong to the same organization.')
      end
    end

    describe 'flow definition schema' do
      it 'is invalid when the definition is not parseable YAML' do
        flow_definition = build(:cd_application_flow_definition, application: application, definition: 'steps: [')

        expect(flow_definition).not_to be_valid
        expect(flow_definition.errors[:definition]).to include(a_string_matching(/not valid YAML/))
      end

      it 'is invalid when the document does not match the orchestration engine schema' do
        flow_definition = build(:cd_application_flow_definition, application: application, definition: "steps: []\n")

        expect(flow_definition).not_to be_valid
        expect(flow_definition.errors[:definition]).to include(a_string_matching(/flow definition:/))
      end

      it 'is invalid when a driver step does not match any registered driver schema' do
        flow_definition = build(:cd_application_flow_definition, application: application, definition: <<~YAML)
          steps:
            - type: com.gitlab.cd.steps.stage
              name: production
              steps:
                - type: com.gitlab.cd.argo.rolling.deploy
                  environment: production
        YAML

        expect(flow_definition).not_to be_valid
        expect(flow_definition.errors[:definition]).to include(a_string_matching(/missing required properties/))
      end

      it 'is valid when a driver step matches a registered driver schema' do
        flow_definition = build(:cd_application_flow_definition, application: application, definition: <<~YAML)
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

        expect(flow_definition).to be_valid
      end
    end
  end

  describe 'immutability' do
    let_it_be(:original) { "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n" }
    let_it_be(:flow_definition) do
      create(:cd_application_flow_definition, application: application, definition: original)
    end

    it 'raises when the definition content is changed' do
      expect { flow_definition.update!(definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 99\n") }
        .to raise_error(ActiveRecord::ReadOnlyRecord)

      expect(flow_definition.reload.definition).to eq(original)
    end

    it 'raises when another attribute is changed' do
      expect { flow_definition.update!(version: 99) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'does not raise when creating a new version' do
      expect { create(:cd_application_flow_definition, application: application) }.not_to raise_error
    end
  end

  describe 'version assignment' do
    it 'assigns version 1 to the first definition for an application' do
      definition = create(:cd_application_flow_definition, application: application)

      expect(definition.version).to eq(1)
    end

    it 'increments the version per application on each save' do
      create(:cd_application_flow_definition, application: application)
      second = create(:cd_application_flow_definition, application: application)

      expect(second.version).to eq(2)
    end

    it 'numbers versions independently per application' do
      other_application = create(:cd_application)
      create(:cd_application_flow_definition, application: application)

      definition = create(:cd_application_flow_definition, application: other_application)

      expect(definition.version).to eq(1)
    end

    it 'ignores an explicitly provided version and assigns the next one instead' do
      definition = create(:cd_application_flow_definition, application: application, version: 5)

      expect(definition.version).to eq(1)
    end
  end

  describe '.ordered' do
    it 'returns definitions newest version first' do
      first = create(:cd_application_flow_definition, application: application)
      second = create(:cd_application_flow_definition, application: application)

      expect(described_class.for_application(application.id).ordered).to eq([second, first])
    end
  end

  describe '#revert_to_previous_version' do
    it 'appends a new version copying the previous version definition' do
      create(:cd_application_flow_definition, application: application,
        definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n")
      latest = create(:cd_application_flow_definition, application: application,
        definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 1\n")

      reverted = latest.revert_to_previous_version

      expect(reverted.version).to eq(3)
      expect(reverted.definition).to eq("steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n")
    end

    it 'preserves the reverted-to version' do
      first = create(:cd_application_flow_definition, application: application)
      latest = create(:cd_application_flow_definition, application: application)

      latest.revert_to_previous_version

      expect(described_class.for_application(application.id)).to include(first)
    end

    it 'reverts using only the application own versions' do
      create(:cd_application_flow_definition, application: application,
        definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n")
      latest = create(:cd_application_flow_definition, application: application,
        definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 1\n")
      create(:cd_application_flow_definition,
        definition: "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 2\n")

      reverted = latest.revert_to_previous_version

      expect(reverted.definition).to eq("steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n")
    end

    it 'returns nil and creates nothing when there is no previous version' do
      only = create(:cd_application_flow_definition, application: application)

      expect { expect(only.revert_to_previous_version).to be_nil }
        .not_to change { described_class.for_application(application.id).count }
    end
  end
end
