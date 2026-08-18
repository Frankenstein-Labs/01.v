# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfileType, feature_category: :security_testing_configuration do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :name,
      :description,
      :scan_type,
      :triggers,
      :gitlab_recommended,
      :configuration,
      :trigger_settings,
      :created_at,
      :updated_at
    )
  end

  it { expect(described_class.graphql_name).to eq('ScanProfileType') }

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'fields' do
    it { expect(described_class).to have_graphql_field(:id, resolver_method: :resolve_id) }
    it { expect(described_class).to have_graphql_field(:name) }
    it { expect(described_class).to have_graphql_field(:description) }
    it { expect(described_class).to have_graphql_field(:scan_type) }
    it { expect(described_class).to have_graphql_field(:triggers) }
    it { expect(described_class).to have_graphql_field(:gitlab_recommended) }
    it { expect(described_class).to have_graphql_field(:configuration) }
    it { expect(described_class).to have_graphql_field(:trigger_settings) }
    it { expect(described_class).to have_graphql_field(:created_at) }
    it { expect(described_class).to have_graphql_field(:updated_at) }
  end

  describe '#resolve_id' do
    let_it_be(:current_user) { create(:user) }

    subject(:resolved_id) { resolve_field(:id, scan_profile, current_user: current_user) }

    context 'when scan profile is persisted' do
      let(:scan_profile) { create(:security_scan_profile) }

      it 'returns the global ID' do
        expect(resolved_id).to eq(scan_profile.to_global_id)
      end

      it 'returns a GlobalID instance' do
        expect(resolved_id).to be_a(GlobalID)
      end

      it 'uses the database ID' do
        expect(resolved_id.model_id).to eq(scan_profile.id.to_s)
      end
    end

    context 'when scan profile is not persisted' do
      let(:scan_profile) do
        build(:security_scan_profile, scan_type: :secret_detection)
      end

      subject(:resolved_id) do
        type_instance = described_class.allocate
        type_instance.instance_variable_set(:@object, scan_profile)
        type_instance.resolve_id
      end

      it 'builds a URI::GID using scan_type' do
        expect(scan_profile.persisted?).to be_falsey
        expect(resolved_id).to be_a(URI::GID)
      end

      it 'uses scan_type as the model_id' do
        expect(resolved_id.model_id).to eq('secret_detection')
      end

      it 'has the correct model_name' do
        expect(resolved_id.model_name).to eq('Security::ScanProfile')
      end

      it 'matches the output of Gitlab::GlobalId.build' do
        expected_id = ::Gitlab::GlobalId.build(scan_profile, id: scan_profile.scan_type)
        expect(resolved_id.to_s).to eq(expected_id.to_s)
      end
    end
  end

  describe '#triggers' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:scan_profile) { create(:security_scan_profile, scan_type: :secret_detection) }
    let_it_be(:pipeline_trigger) do
      create(:security_scan_profile_trigger, scan_profile: scan_profile, trigger_type: :default_branch_pipeline)
    end

    let_it_be(:non_pipeline_trigger) do
      create(:security_scan_profile_trigger, scan_profile: scan_profile, trigger_type: :git_push_event)
    end

    subject(:resolved_triggers) { resolve_field(:triggers, scan_profile.reload, current_user: current_user) }

    it 'returns all trigger types' do
      expect(resolved_triggers).to contain_exactly('default_branch_pipeline', 'git_push_event')
    end
  end

  describe '#configuration' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:scan_profile) do
      create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group)
    end

    subject(:resolved_configuration) do
      resolve_field(:configuration, scan_profile, current_user: current_user)
    end

    context 'with a configured sbom_ingested trigger' do
      before_all do
        create(:security_scan_profile_trigger, scan_profile: scan_profile, trigger_type: :sbom_ingested,
          configuration_values: { 'auto_remediation' => { 'severity_level' => 'critical' } })
      end

      it 'returns the trigger effective configuration, merging overrides with defaults', :aggregate_failures do
        expect(resolved_configuration.dig(:auto_remediation, :severity_level)).to eq('critical')
        expect(resolved_configuration.dig(:auto_remediation, :cooldown)).to eq(7)
      end
    end

    context 'without an sbom_ingested trigger' do
      it 'returns an empty hash' do
        expect(resolved_configuration).to eq({})
      end
    end

    context 'when the profile is not a remediation profile' do
      let_it_be_with_reload(:scan_profile) do
        create(:security_scan_profile, :sast, namespace: group)
      end

      it 'returns an empty hash rather than defaults' do
        expect(resolved_configuration).to eq({})
      end
    end
  end

  describe 'field scopes' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name, :scopes) do
      'configuration'     | %i[api read_api ai_workflows]
      'triggerSettings'   | %i[api read_api ai_workflows]
      'createdAt'         | %i[api read_api ai_workflows]
      'description'       | %i[api read_api ai_workflows]
      'gitlabRecommended' | %i[api read_api ai_workflows]
      'id'                | %i[api read_api ai_workflows]
      'name'              | %i[api read_api ai_workflows]
      'scanType'          | %i[api read_api ai_workflows]
      'triggers'          | %i[api read_api ai_workflows]
      'updatedAt'         | %i[api read_api ai_workflows]
    end

    with_them do
      let(:field) { described_class.fields[field_name] }

      subject { field.scopes }

      it { is_expected.to match_array(scopes) }
    end
  end
end
