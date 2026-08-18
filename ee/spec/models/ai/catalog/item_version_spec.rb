# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersion, feature_category: :workflow_catalog do
  subject(:version) { build_stubbed(:ai_catalog_item_version) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:item).required }
    it { is_expected.to belong_to(:created_by).class_name('User').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:definition) }
    it { is_expected.to validate_presence_of(:schema_version) }
    it { is_expected.to validate_presence_of(:version) }

    it { is_expected.to validate_length_of(:version).is_at_most(50) }

    it { is_expected.to allow_value('1.1.1', '999.999.999').for(:version) }
    it { is_expected.not_to allow_value('1.1.1.', '1.1', '1', "hello\n1.0.0\nworld").for(:version) }

    describe 'dangerous characters validation' do
      subject(:version) { build_stubbed(:ai_catalog_agent_version) }

      let(:user_prompt) { 'prompt' }

      before do
        version.definition['user_prompt'] = user_prompt
      end

      it { is_expected.to be_valid }

      context 'when definition contains dangerous characters' do
        let(:user_prompt) { 'prompt󠁈󠁩󠁤󠁤󠁥󠁮󠀠󠁣󠁨󠁡󠁲󠁳' } # Contains invisible characters.

        it { is_expected.not_to be_valid }
      end
    end

    describe 'definition json_schema' do
      context 'when item is an agent' do
        subject(:version) { build_stubbed(:ai_catalog_agent_version) }

        it { is_expected.to be_valid }

        context 'when definition is invalid' do
          before do
            version.definition['something'] = 1
          end

          it { is_expected.not_to be_valid }
        end

        context 'when user_prompt is an empty string' do
          before do
            version.definition['user_prompt'] = ''
          end

          it { is_expected.to be_valid }
        end

        context 'when validating mcp_tools maxItems limit' do
          it 'is valid with 100 items' do
            version.definition['mcp_tools'] = Array.new(100) { |i| "gitlab_mcp_#{i}" }

            expect(version).to be_valid
          end

          it 'is not valid with 101 items' do
            version.definition['mcp_tools'] = Array.new(101) { |i| "gitlab_mcp_#{i}" }

            expect(version).not_to be_valid
            expect(version.errors['definition']).to include(
              "array size at `/mcp_tools` is greater than: 100"
            )
          end
        end
      end

      context 'when item is a flow' do
        subject(:version) { build_stubbed(:ai_catalog_flow_version) }

        it { is_expected.to be_valid }

        context 'when definition is invalid' do
          before do
            version.definition['something'] = 1
          end

          it { is_expected.not_to be_valid }
        end

        context 'when definition has invalid types for required properties' do
          before do
            version.definition['version'] = 123
            version.definition['environment'] = nil
            version.definition['components'] = 'not an array'
            version.definition['routers'] = true
            version.definition['flow'] = 'not an object'
          end

          it "adds validation errors for each invalid property type and value" do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "value at `/version` is not a string",
              "value at `/version` is not: v1",
              "value at `/environment` is not a string",
              "value at `/environment` is not one of: [\"ambient\"]",
              "value at `/components` is not an array",
              "value at `/routers` is not an array",
              "value at `/flow` is not an object"
            )
          end
        end

        context 'when a component has a known type with a missing required property' do
          before do
            version.definition['components'] = [{ 'name' => 'a', 'type' => 'AgentComponent' }]
          end

          it 'reports exactly one error identifying the missing property', :aggregate_failures do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "object at `/components/0` is missing required properties: prompt_id"
            )
          end
        end

        context 'when a component has an unknown type' do
          before do
            version.definition['components'] = [{ 'name' => 'a', 'type' => 'UnknownComponent' }]
          end

          it 'reports exactly one error identifying the invalid type value', :aggregate_failures do
            expect(version).not_to be_valid
            expect(version.errors['definition'].size).to eq(1)
            expect(version.errors['definition'].first).to include(
              'is not one of:',
              'AgentComponent'
            )
          end
        end

        context 'when a component is missing the type field entirely' do
          before do
            version.definition['components'] = [{ 'name' => 'a' }]
          end

          it 'reports exactly one error identifying the missing type field', :aggregate_failures do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "object at `/components/0` is missing required properties: type"
            )
          end
        end

        context 'when definition has an AgentComponent toolset object with multiple tool keys' do
          before do
            version.definition['components'][0]['toolset'] = [
              { 'tool_a' => { 'opt' => true }, 'tool_b' => { 'opt' => false } }
            ]
          end

          it { is_expected.to be_valid }
        end

        context 'when definition has a OneOffComponent with object-style toolset entries' do
          before do
            version.definition['components'] = [
              {
                'name' => 'my_component',
                'type' => 'OneOffComponent',
                'prompt_id' => 'test_prompt',
                'toolset' => [{ 'create_merge_request_note' => { 'internal' => true } }]
              }
            ]
          end

          it { is_expected.to be_valid }
        end

        context 'when definition has a OneOffComponent with a mixed toolset' do
          before do
            version.definition['components'] = [
              {
                'name' => 'my_component',
                'type' => 'OneOffComponent',
                'prompt_id' => 'test_prompt',
                'toolset' => ['read_file', { 'create_merge_request_note' => { 'internal' => true } }]
              }
            ]
          end

          it { is_expected.to be_valid }
        end

        context 'when definition has a OneOffComponent with a string-only toolset' do
          before do
            version.definition['components'] = [
              {
                'name' => 'my_component',
                'type' => 'OneOffComponent',
                'prompt_id' => 'test_prompt',
                'toolset' => ['read_file']
              }
            ]
          end

          it { is_expected.to be_valid } # regression guard
        end

        context 'when prompts are defined with valid params' do
          before do
            version.definition['prompts'] = [
              {
                'prompt_id' => 'test_prompt',
                'name' => 'Test Prompt',
                'prompt_template' => {
                  'system' => 'You are a helpful assistant'
                },
                'unit_primitives' => [],
                'params' => {
                  'timeout' => 30,
                  'vertex_location' => 'global'
                }
              }
            ]
          end

          it { is_expected.to be_valid }
        end

        context 'when definition has an AgentComponent in supervisor mode' do
          let(:supervisor_agent_component) do
            {
              'name' => 'supervisor_agent',
              'type' => 'AgentComponent',
              'prompt_id' => 'supervisor_prompt',
              'subagents' => [{ 'name' => 'worker_agent' }]
            }
          end

          let(:worker_agent_component) do
            {
              'name' => 'worker_agent',
              'type' => 'AgentComponent',
              'prompt_id' => 'worker_prompt',
              'description' => 'A worker agent that executes tasks.'
            }
          end

          before do
            version.definition['components'] = [supervisor_agent_component, worker_agent_component]
          end

          it { is_expected.to be_valid }

          context 'with supervisor ui_log_events including on_delegation and on_delegation_returns' do
            let(:supervisor_agent_component) do
              super().merge(
                'ui_log_events' => %w[on_agent_final_answer on_delegation on_delegation_returns]
              )
            end

            it { is_expected.to be_valid }
          end

          context 'with only on_delegation ui_log_event' do
            let(:supervisor_agent_component) do
              super().merge('ui_log_events' => ['on_delegation'])
            end

            it { is_expected.to be_valid }
          end

          context 'with only on_delegation_returns ui_log_event' do
            let(:supervisor_agent_component) do
              super().merge('ui_log_events' => ['on_delegation_returns'])
            end

            it { is_expected.to be_valid }
          end

          context 'with all valid ui_log_events for supervisor mode' do
            let(:supervisor_agent_component) do
              super().merge(
                'ui_log_events' => %w[
                  on_agent_final_answer
                  on_tool_execution_success
                  on_tool_execution_failed
                  on_delegation
                  on_delegation_returns
                ]
              )
            end

            it { is_expected.to be_valid }
          end

          context 'with max_delegations set' do
            let(:supervisor_agent_component) { super().merge('max_delegations' => 20) }

            it { is_expected.to be_valid }
          end

          context 'when max_delegations is less than 1' do
            let(:supervisor_agent_component) { super().merge('max_delegations' => 0) }

            it { is_expected.not_to be_valid }
          end

          context 'when subagents entry contains invalid component name characters' do
            let(:supervisor_agent_component) do
              super().merge('subagents' => [{ 'name' => 'invalid.component:name' }])
            end

            it { is_expected.not_to be_valid }
          end

          context 'when subagents entry contains unknown properties' do
            let(:supervisor_agent_component) do
              super().merge('subagents' => [{ 'name' => 'worker_agent', 'unknown' => 'value' }])
            end

            it { is_expected.not_to be_valid }
          end

          context 'when an unknown property is present on the supervisor component' do
            let(:supervisor_agent_component) { super().merge('unknown_field' => 'value') }

            it { is_expected.not_to be_valid }
          end

          context 'when subagents is an empty array' do
            let(:supervisor_agent_component) { super().merge('subagents' => []) }

            it { is_expected.to be_valid }
          end

          context 'when subagents contains multiple valid component names' do
            let(:supervisor_agent_component) do
              super().merge('subagents' => [{ 'name' => 'worker_agent_1' }, { 'name' => 'worker_agent_2' }])
            end

            it { is_expected.to be_valid }
          end

          context 'with model_size_preference set to small' do
            let(:supervisor_agent_component) { super().merge('model_size_preference' => 'small') }

            it { is_expected.to be_valid }
          end

          context 'with model_size_preference set to large' do
            let(:supervisor_agent_component) { super().merge('model_size_preference' => 'large') }

            it { is_expected.to be_valid }
          end

          context 'when model_size_preference has an invalid value' do
            let(:supervisor_agent_component) { super().merge('model_size_preference' => 'medium') }

            it { is_expected.not_to be_valid }
          end
        end

        context 'when definition has an AgentComponent with description (managed/subagent mode)' do
          let(:agent_with_description) do
            {
              'name' => 'worker_agent',
              'type' => 'AgentComponent',
              'prompt_id' => 'worker_prompt',
              'description' => 'Implements code changes, creates and edits files.'
            }
          end

          before do
            version.definition['components'] = [agent_with_description]
          end

          it { is_expected.to be_valid }
        end

        context 'when definition has an AgentComponent with model_size_preference' do
          before do
            version.definition['components'][0]['model_size_preference'] = 'small'
          end

          it { is_expected.to be_valid }

          context 'when model_size_preference is large' do
            before do
              version.definition['components'][0]['model_size_preference'] = 'large'
            end

            it { is_expected.to be_valid }
          end

          context 'when model_size_preference has an invalid value' do
            before do
              version.definition['components'][0]['model_size_preference'] = 'medium'
            end

            it { is_expected.not_to be_valid }
          end
        end

        context 'when definition has a HumanInputComponent' do
          let(:human_input_component) do
            {
              'name' => 'ask_user',
              'type' => 'HumanInputComponent',
              'sends_response_to' => 'planning_agent',
              'message_template' => 'Please review the plan and provide your feedback'
            }
          end

          before do
            version.definition['components'] = [human_input_component]
          end

          it { is_expected.to be_valid }

          context 'with interaction_type approval' do
            let(:human_input_component) { super().merge('interaction_type' => 'approval') }

            it { is_expected.to be_valid }
          end

          context 'with interaction_type input' do
            let(:human_input_component) { super().merge('interaction_type' => 'input') }

            it { is_expected.to be_valid }
          end

          context 'with all optional fields' do
            let(:human_input_component) do
              super().merge(
                'interaction_type' => 'approval',
                'inputs' => [{ 'from' => 'context:planner_agent.final_answer', 'as' => 'proposed_changes' }],
                'ui_log_events' => %w[on_user_input_prompt on_user_response]
              )
            end

            it { is_expected.to be_valid }
          end

          context 'when sends_response_to is missing' do
            let(:human_input_component) { super().except('sends_response_to') }

            it { is_expected.not_to be_valid }
          end

          context 'when message_template is missing' do
            let(:human_input_component) { super().except('message_template') }

            it { is_expected.not_to be_valid }
          end

          context 'when interaction_type is invalid' do
            let(:human_input_component) { super().merge('interaction_type' => 'unknown') }

            it { is_expected.not_to be_valid }
          end

          context 'when toolset is present' do
            let(:human_input_component) { super().merge('toolset' => ['some_tool']) }

            it { is_expected.not_to be_valid }
          end

          context 'when ui_log_events contains an invalid value' do
            let(:human_input_component) { super().merge('ui_log_events' => ['on_agent_final_answer']) }

            it { is_expected.not_to be_valid }
          end

          context 'when sends_response_to contains invalid characters' do
            let(:human_input_component) { super().merge('sends_response_to' => 'some.component:name') }

            it { is_expected.not_to be_valid }
          end

          context 'when an unknown property is present' do
            let(:human_input_component) { super().merge('unknown_field' => 'value') }

            it { is_expected.not_to be_valid }
          end
        end

        context 'with coding_environment property' do
          using RSpec::Parameterized::TableSyntax

          where(:coding_environment, :valid) do
            :absent       | true
            'full'        | true
            'none'        | true
            'lightweight' | false
            42            | false
          end

          with_them do
            before do
              version.definition['coding_environment'] = coding_environment unless coding_environment == :absent
            end

            it { expect(version.valid?).to eq(valid) }
          end

          it 'reports the enum path for an unrecognised value' do
            version.definition['coding_environment'] = 'lightweight'

            expect(version).not_to be_valid
            expect(version.errors['definition']).to include(a_string_including('/coding_environment'))
          end
        end
      end

      context 'when item is third party flow' do
        subject(:version) { build_stubbed(:ai_catalog_third_party_flow_version) }

        it { is_expected.to be_valid }

        context 'when definition has invalid image, commands, injectGatewayToken or variables' do
          before do
            version.definition['image'] = 123
            version.definition['commands'] = { a: :b }
            version.definition['injectGatewayToken'] = 'yes'
            version.definition['variables'] = nil
          end

          it "adds errors for all the attributes" do
            expect(version).not_to be_valid
            expect(version.errors['definition']).to contain_exactly(
              "value at `/commands` is not an array",
              "value at `/image` is not a string",
              "value at `/injectGatewayToken` is not a boolean",
              "value at `/variables` is not an array"
            )
          end
        end
      end

      context 'when item is nil' do
        it 'cannot validate definition schema' do
          version.item = nil

          expect(version).not_to be_valid
          expect(version.errors[:definition]).to include('unable to validate definition')
        end
      end

      context 'when schema_version is nil' do
        it 'cannot validate definition schema' do
          version.schema_version = nil

          expect(version).not_to be_valid
          expect(version.errors[:definition]).to include('unable to validate definition')
        end
      end
    end

    describe 'definition size' do
      let(:yaml_size_error) { 'YAML is too large. Maximum size is 40 KiB' }

      context 'when item is a flow' do
        subject(:version) { build_stubbed(:ai_catalog_flow_version) }

        context 'when the yaml source is within the limit' do
          before do
            version.definition['yaml_definition'] = 'a' * (described_class::YAML_DEFINITION_SIZE_LIMIT - 100)
          end

          it 'is valid even though the yaml source exceeds half the definition limit once stored' do
            expect(Gitlab::Json.dump(version.definition).bytesize)
              .to be > described_class::YAML_DEFINITION_SIZE_LIMIT

            expect(version).to be_valid
          end
        end

        context 'when the yaml source exceeds the limit' do
          before do
            version.definition['yaml_definition'] = 'a' * (described_class::YAML_DEFINITION_SIZE_LIMIT + 1)
            version.definition['components'] = 'not an array'
          end

          it 'reports only the yaml size error' do
            expect(version).not_to be_valid
            expect(version.errors[:definition]).to contain_exactly(yaml_size_error)
          end
        end
      end

      context 'when item is a third_party_flow' do
        subject(:version) { build_stubbed(:ai_catalog_third_party_flow_version) }

        context 'when the yaml source exceeds the limit' do
          before do
            version.definition['yaml_definition'] = 'a' * (described_class::YAML_DEFINITION_SIZE_LIMIT + 1)
          end

          it 'is not valid' do
            expect(version).not_to be_valid
            expect(version.errors[:definition]).to contain_exactly(yaml_size_error)
          end
        end
      end

      context 'when item is an agent' do
        subject(:version) { build_stubbed(:ai_catalog_agent_version) }

        context 'when the definition exceeds the limit' do
          before do
            version.definition['system_prompt'] = 'a' * (described_class::DEFINITION_SIZE_LIMIT + 1)
          end

          it 'is not valid' do
            expect(version).not_to be_valid
            expect(version.errors[:definition])
              .to contain_exactly('is too large. Maximum size allowed is 80 KiB')
          end
        end
      end
    end

    describe '#require_dws_flow_config_validation' do
      context 'when item is nil' do
        subject(:version) { build(:ai_catalog_agent_version, dws_flow_config_validated: false) }

        before do
          version.item = nil
        end

        it 'skips validation' do
          version.valid?

          expect(version.errors[:base]).not_to include(
            'Agent definition must be validated by Duo Workflow Service before saving'
          )
        end
      end

      context 'when item is a custom flow with a new record' do
        subject(:version) { build(:ai_catalog_flow_version, dws_flow_config_validated: false) }

        it 'is invalid when dws_flow_config_validated is falsy' do
          expect(version).not_to be_valid
          expect(version.errors[:base]).to include(
            'Flow definition must be validated by Duo Workflow Service before saving'
          )
        end

        context 'when dws_flow_config_validated is true' do
          subject(:version) { build(:ai_catalog_flow_version) }

          it { is_expected.to be_valid }
        end
      end

      context 'when item is a custom agent with a new record' do
        subject(:version) { build(:ai_catalog_agent_version, dws_flow_config_validated: false) }

        it 'is invalid when dws_flow_config_validated is falsy' do
          expect(version).not_to be_valid
          expect(version.errors[:base]).to include(
            'Agent definition must be validated by Duo Workflow Service before saving'
          )
        end

        context 'when dws_flow_config_validated is true' do
          subject(:version) { build(:ai_catalog_agent_version) }

          it { is_expected.to be_valid }
        end
      end

      context 'when item is a flow with no definition change' do
        subject(:version) { create(:ai_catalog_flow_version) }

        it 'skips validation on persisted record without definition change' do
          version.dws_flow_config_validated = false

          expect(version).to be_valid
        end
      end
    end

    describe '#validate_readonly' do
      it 'can be changed if version is draft' do
        version = create(:ai_catalog_item_version)
        version.release_date = Time.zone.now

        expect(version).to be_valid
      end

      it 'cannot be changed if version is released' do
        version = create(:ai_catalog_item_version, :released)
        version.release_date = Time.zone.now

        expect(version).not_to be_valid
        expect(version.errors[:base]).to include('can\'t be changed because it is released')
      end

      it 'can update deprecated on a released version' do
        version = create(:ai_catalog_item_version, :released)
        version.deprecated = true

        expect(version).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :populate_organization' do
      subject(:version) { create(:ai_catalog_item_version) }

      it 'assigns organization from item' do
        expect(version.organization).to eq(version.item.organization)
      end
    end
  end

  describe 'scopes' do
    let_it_be_with_reload(:item) { create(:ai_catalog_item, :public) }
    let_it_be(:original_version) { item.latest_version }

    describe '.created_after' do
      it 'returns the expected versions' do
        new_version = create(:ai_catalog_item_version, item: item, created_at: Date.tomorrow + 1.hour)

        results = described_class.created_after(Date.tomorrow)

        expect(results).to contain_exactly(new_version)
      end
    end

    describe '.for_public_items' do
      it 'returns the expected versions' do
        create(:ai_catalog_item, :private)

        results = described_class.for_public_items

        expect(results).to contain_exactly(original_version)
      end
    end

    describe '.in_organization' do
      it 'returns the expected versions' do
        create(:ai_catalog_item, organization: create(:organization))

        results = described_class.in_organization(item.organization)

        expect(results).to contain_exactly(original_version)
      end
    end

    describe '.not_deprecated' do
      it 'returns only non-deprecated versions' do
        create(:ai_catalog_item_version, :deprecated, item: item)

        results = described_class.not_deprecated

        expect(results).to contain_exactly(original_version)
      end
    end

    describe '.released' do
      it 'returns only released versions' do
        released_version = create(:ai_catalog_item_version, :released, item: item)

        results = described_class.released

        expect(results).to contain_exactly(released_version)
      end
    end

    describe '.order_by_id_desc' do
      it 'returns the expected versions' do
        new_version = create(:ai_catalog_item_version, item: item)

        results = described_class.order_by_id_desc

        expect(results).to eq([new_version, original_version])
      end
    end

    describe '.with_organization' do
      it 'preloads the organization association' do
        version = described_class.with_organization.where(id: original_version.id).first

        expect(version.association(:organization)).to be_loaded
      end
    end

    describe '.for_item_version_pairs' do
      let_it_be_with_reload(:other_item) { create(:ai_catalog_item, :public) }
      let_it_be(:item_v1) { create(:ai_catalog_item_version, item: item, version: '1.0.0') }
      let_it_be(:item_v2) { create(:ai_catalog_item_version, item: item, version: '2.0.0') }
      let_it_be(:other_item_v2) { create(:ai_catalog_item_version, item: other_item, version: '2.0.0') }

      it 'returns only the versions matching the exact item and version pairs' do
        results = described_class.for_item_version_pairs([[item.id, '1.0.0'], [other_item.id, '2.0.0']])

        expect(results).to contain_exactly(item_v1, other_item_v2)
      end

      it 'excludes a version whose item matches but version does not' do
        results = described_class.for_item_version_pairs([[item.id, '2.0.0']])

        expect(results).to contain_exactly(item_v2)
      end
    end
  end

  describe '#human_version' do
    it 'returns nil when version is nil' do
      expect(build(:ai_catalog_item_version, version: nil).human_version).to be_nil
    end

    it 'returns version prefixed with v when released' do
      expect(
        build(:ai_catalog_item_version, :released, version: '1.2.3').human_version
      ).to eq('v1.2.3')
    end

    it 'returns version prefixed with v and suffixed with -draft when draft' do
      expect(build(:ai_catalog_item_version, version: '1.2.3').human_version).to eq('v1.2.3-draft')
    end
  end

  describe '#version_bump' do
    subject(:version) { build(:ai_catalog_item_version, version: '1.2.3') }

    it 'returns nil if version is nil' do
      version.version = nil

      expect(version.version_bump(:major)).to be_nil
    end

    it 'can return major version bunp' do
      expect(version.version_bump(:major)).to eq('2.0.0')
    end

    it 'can return minor version bunp' do
      expect(version.version_bump(:minor)).to eq('1.3.0')
    end

    it 'can return patch version bunp' do
      expect(version.version_bump(:patch)).to eq('1.2.4')
    end

    it 'raises an error if bump level is unknown' do
      expect { version.version_bump(:foo) }.to raise_error(ArgumentError, 'unknown bump_level: foo')
    end
  end

  describe '#released?' do
    it 'returns false when release_date is nil' do
      expect(build(:ai_catalog_item_version, release_date: nil)).not_to be_released
    end

    it 'returns true when release_date is present' do
      expect(build(:ai_catalog_item_version, release_date: Time.zone.now)).to be_released
    end
  end

  describe '#draft?' do
    it 'returns true when release_date is nil' do
      expect(build(:ai_catalog_item_version, release_date: nil)).to be_draft
    end

    it 'returns false when release_date is present' do
      expect(build(:ai_catalog_item_version, release_date: Time.zone.now)).not_to be_draft
    end
  end

  describe '#respond_to?' do
    subject(:version) { build_stubbed(:ai_catalog_item_version) }

    context 'when method starts with "def_"' do
      it 'returns true' do
        expect(version.respond_to?(:def_system_prompt)).to be(true)
      end
    end

    context 'when method does not start with "def_"' do
      it 'returns false' do
        expect(version.respond_to?(:unknown_method)).to be(false)
      end
    end
  end

  describe '#method_missing' do
    subject(:version) { build_stubbed(:ai_catalog_item_version) }

    it 'provides access to top level definition attributes' do
      expect(version.def_system_prompt).to eq('Talk like a pirate!')
    end
  end
end
