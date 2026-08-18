# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspacesAgentConfig, feature_category: :workspaces do
  let_it_be_with_reload(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let(:default_default_resources_per_workspace_container) { {} }
  let(:default_max_resources_per_workspace) { {} }
  let(:default_network_policy_egress) do
    [
      {
        "allow" => "0.0.0.0/0",
        "except" => [
          -"10.0.0.0/8",
          -"172.16.0.0/12",
          -"192.168.0.0/16"
        ]
      }
    ]
  end

  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "" }
  let(:shared_namespace) { "" }

  subject(:config) { agent.unversioned_latest_workspaces_agent_config }

  describe "database defaults" do
    let_it_be(:agent_config_with_defaults) { described_class.new }

    where(:field) do
      %i[
        allow_privilege_escalation
        annotations
        default_resources_per_workspace_container
        default_runtime_class
        gitlab_workspaces_proxy_http_enabled
        gitlab_workspaces_proxy_namespace
        gitlab_workspaces_proxy_ssh_enabled
        labels
        max_active_hours_before_stop
        max_resources_per_workspace
        max_stopped_hours_before_termination
        network_policy_egress
        network_policy_enabled
        use_kubernetes_user_namespaces
        workspaces_per_user_quota
        workspaces_quota
        shared_namespace
      ].map { |field| [field] }
    end

    with_them do
      it "have same defaults as the Settings defaults" do
        default_value_from_db = agent_config_with_defaults.send(field)
        default_value_from_db.each(&:deep_symbolize_keys!) if [:network_policy_egress].include?(field)
        expect(default_value_from_db).to eq(RemoteDevelopment::Settings.get_single_setting(field))
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:agent) }
    it { is_expected.to have_many(:workspaces) }

    context 'with associated workspaces' do
      let(:workspace_1) { create(:workspace, agent: agent) }
      let(:workspace_2) { create(:workspace, agent: agent) }

      it 'has correct associations from factory' do
        expect(config.reload.workspaces).to contain_exactly(workspace_1, workspace_2)
        expect(workspace_1.workspaces_agent_config).to eq(config)
      end
    end
  end

  describe 'validations' do
    context 'for dns_zone' do
      using RSpec::Parameterized::TableSyntax

      where(:dns_zone, :gitlab_workspaces_proxy_http_enabled, :validity, :errors) do
        # rubocop:disable Layout/LineLength -- we want single lines for RSpec::Parameterized::TableSyntax
        "1.domain.com"          | true  | be_valid   | []
        "example.1.domain.com"  | true  | be_valid   | []
        ""                      | false | be_valid   | []
        nil                     | false | be_valid   | []
        # noinspection RubyResolve -- RubyMine cannot find matchers that works general predicate matcher system
        "invalid dns"           | true  | be_invalid | ["contains invalid characters (valid characters: [a-z0-9\\-])"]
        ""                      | true  | be_invalid | ["must be between 1 and 255 characters long", "can't be blank when gitlab_workspaces_proxy_http_enabled is true"]
        nil                     | true  | be_invalid | ["must be between 1 and 255 characters long", "can't be blank when gitlab_workspaces_proxy_http_enabled is true"]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        subject(:config) do
          build(
            :workspaces_agent_config,
            dns_zone: dns_zone,
            gitlab_workspaces_proxy_http_enabled: gitlab_workspaces_proxy_http_enabled
          )
        end

        it 'validates' do
          expect(config).to validity
          expect(config.errors[:dns_zone]).to eq(errors)
        end
      end
    end

    context 'for image_pull_secrets' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      using RSpec::Parameterized::TableSyntax

      where(:image_pull_secrets, :validity, :errors) do
        # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
        nil                            | false | ["must be an array of hashes"]
        'not-an-array'                 | false | ["must be an array of hashes"]
        [nil]                          | false | ["must be an array of hashes containing 'name' and 'namespace' attributes of type string"]
        [{ namespace: 'namespace-a' }] | false | ["must be an array of hashes containing 'name' and 'namespace' attributes of type string"]
        [{ name: 'secret-a' }]         | false | ["must be an array of hashes containing 'name' and 'namespace' attributes of type string"]
        []                             | true  | []
        [{ name: 'secret-a', namespace: 'namespace-a' }, { name: 'secret-b', namespace: 'namespace-b' }] | true  | []
        [{ name: 'secret-a', namespace: 'namespace-a' }, { name: 'secret-a', namespace: 'namespace-b' }] | false | ["name: secret-a exists in more than one image pull secret, image pull secrets must have a unique 'name'"]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        before do
          config.image_pull_secrets = image_pull_secrets
          config.validate
        end

        it { expect(config.valid?).to eq(validity) }
        it { expect(config.errors[:image_pull_secrets]).to eq(errors) }
      end
    end

    context 'when image_pull_secrets and shared_namespace are specified' do
      using RSpec::Parameterized::TableSyntax

      where(:shared_namespace, :image_pull_secrets, :validity, :error_field, :errors) do
        # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
        ''               | []                                                         | true  | :image_pull_secrets | []
        ''               | [{ name: 'secret-a', namespace: 'my-namespace' }]          | true  | :image_pull_secrets | []
        'my-namespace'   | []                                                         | true  | :image_pull_secrets | []
        'my-namespace'   | [{ name: 'secret-a', namespace: 'my-namespace' }]          | true  | :image_pull_secrets | []
        'my-namespace'   | [{ name: 'secret-a', namespace: 'different-namespace' }]   | false | :image_pull_secrets | ["image_pull_secrets.namespace and shared_namespace must match if shared_namespace is specified"]
        'my-namespace'   | [{ name: 'secret-a', namespace: 'my-namespace' }, { name: 'secret-b', namespace: 'different-namespace' }] | false | :image_pull_secrets | ["image_pull_secrets.namespace and shared_namespace must match if shared_namespace is specified"]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        before do
          config.shared_namespace = shared_namespace
          config.image_pull_secrets = image_pull_secrets
          config.validate
        end

        it { expect(config.valid?).to eq(validity) }
        it { expect(config.errors[error_field]).to eq(errors) }
      end
    end

    context 'when config has allow_privilege_escalation set to true' do
      let(:allow_privilege_escalation) { true }

      subject(:config) { build(:workspaces_agent_config, allow_privilege_escalation: true) }

      it 'prevents config from being created' do
        expect { config.save! }.to raise_error(
          ActiveRecord::RecordInvalid,
          "Validation failed: Allow privilege escalation can be true only if " \
            "either use_kubernetes_user_namespaces is true or default_runtime_class is non-empty"
        )
      end

      context 'when use_kubernetes_user_namespaces is set to true' do
        let(:use_kubernetes_user_namespaces) { true }

        subject(:config) do
          build(
            :workspaces_agent_config,
            allow_privilege_escalation: allow_privilege_escalation,
            use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
          )
        end

        it 'allows the config to be created' do
          expect(config).to be_valid
          expect(config.allow_privilege_escalation).to eq(allow_privilege_escalation)
          expect(config.use_kubernetes_user_namespaces).to eq(use_kubernetes_user_namespaces)
        end
      end

      context 'when default_runtime_class is set to non-empty value' do
        let(:default_runtime_class) { "test" }

        subject(:config) do
          build(
            :workspaces_agent_config,
            allow_privilege_escalation: allow_privilege_escalation,
            default_runtime_class: default_runtime_class
          )
        end

        it 'allows the config to be created' do
          expect(config).to be_valid
          expect(config.allow_privilege_escalation).to be(true)
          expect(config.default_runtime_class).to eq(default_runtime_class)
        end
      end

      context 'when shared_namespace is set to non-empty value' do
        let(:shared_namespace) { "test" }

        subject(:config) do
          build(
            :workspaces_agent_config,
            shared_namespace: shared_namespace
          )
        end

        it 'allows the config to be created' do
          expect(config).to be_valid
          expect(config.shared_namespace).to eq(shared_namespace)
        end
      end
    end

    context 'when max_resources_per_workspace and shared_namespace are specified' do
      using RSpec::Parameterized::TableSyntax

      where(:shared_namespace, :max_resources_per_workspace, :validity, :error_field, :errors) do
        # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
        ''               | {}                                                                              | true  | :max_resources_per_workspace | []
        ''               | { requests: { cpu: "1", memory: "1Gi" }, limits: { cpu: "2", memory: "2Gi" } }  | true  | :max_resources_per_workspace | []
        ''               | nil                                                                             | false | :max_resources_per_workspace | ["must be a valid json schema", "must be a hash"]
        'my-namespace'   | {}                                                                              | true  | :max_resources_per_workspace | []
        'my-namespace'   | nil                                                                             | false | :max_resources_per_workspace | ["must be a valid json schema", "must be a hash"]
        'my-namespace'   | { requests: { cpu: "1", memory: "1Gi" }, limits: { cpu: "2", memory: "2Gi" } }  | false | :max_resources_per_workspace | ["max_resources_per_workspace must be an empty hash if shared_namespace is specified"]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        before do
          config.shared_namespace = shared_namespace
          config.max_resources_per_workspace = max_resources_per_workspace
          config.validate
        end

        it { expect(config.valid?).to eq(validity) }
        it { expect(config.errors[error_field]).to eq(errors) }
      end
    end

    it 'when network_policy_egress is not specified explicitly' do
      expect(config).to be_valid
      expect(config.network_policy_egress).to eq(default_network_policy_egress)
    end

    it 'when network_policy_egress is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.network_policy_egress = nil
      expect(config).not_to be_valid
      expect(config.errors[:network_policy_egress]).to include(
        'must be a valid json schema',
        'must be an array'
      )
    end

    it 'when default_resources_per_workspace_container is not specified explicitly' do
      expect(config).to be_valid
      expect(config.default_resources_per_workspace_container).to eq(default_default_resources_per_workspace_container)
    end

    it 'when default_resources_per_workspace_container is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.default_resources_per_workspace_container = nil
      expect(config).not_to be_valid
      expect(config.errors[:default_resources_per_workspace_container]).to include(
        'must be a valid json schema',
        'must be a hash'
      )
    end

    it 'when max_resources_per_workspace is not specified explicitly' do
      expect(config).to be_valid
      expect(config.max_resources_per_workspace).to eq(default_max_resources_per_workspace)
    end

    it 'when default_resources_per_workspace_container is nil' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.max_resources_per_workspace = nil
      expect(config).not_to be_valid
      expect(config.errors[:max_resources_per_workspace]).to include(
        'must be a valid json schema',
        'must be a hash'
      )
    end

    it 'allows numerical values for workspaces_quota greater or equal to -1' do
      is_expected.to validate_numericality_of(:workspaces_quota).only_integer.is_greater_than_or_equal_to(-1)
    end

    it 'allows numerical values for workspaces_per_user_quota greater or equal to -1' do
      is_expected.to validate_numericality_of(:workspaces_per_user_quota).only_integer.is_greater_than_or_equal_to(-1)
    end

    it 'allows numerical values for max_active_hours_before_stop greater or equal to 1' do
      is_expected.to validate_numericality_of(:max_active_hours_before_stop)
                       .only_integer.is_greater_than_or_equal_to(1)
    end

    it 'allows numerical values for max_stopped_hours_before_termination greater or equal to 1' do
      is_expected.to validate_numericality_of(:max_stopped_hours_before_termination)
                       .only_integer.is_greater_than_or_equal_to(1)
    end

    it 'prevents max_active_hours_before_stop + max_stopped_hours_before_termination > 1 year' do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.max_active_hours_before_stop = 8760
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      config.max_stopped_hours_before_termination = 1
      expect(config).not_to be_valid
      expect(config.errors[:base]).to include(
        "Sum of max_active_hours_before_stop and max_stopped_hours_before_termination must not exceed 8760 hours"
      )
    end
  end

  describe "when using 'with_overrides_for_all_possible_config_values' factory trait" do
    it "ensures that all possible config values are set", :unlimited_max_formatted_output_length do
      # NOTE: If this spec fails while adding a new field or attribute to
      #       the WorkspacesAgentConfig model, and it is a value that comes from
      #       the agent config file then you need to update
      #       `ee/spec/fixtures/remote_development/example.agent_config.yaml`
      #       to include the new field or attribute with a non-default value,
      #       then update the list below to include the attribute.
      #
      #       If it is a value that does not come from the agent config file, then you can just update the list.
      #
      #       And don't forget to update the example at `doc/user/workspace/settings.md` too!

      known_attributes = %w[
        allow_privilege_escalation
        annotations
        cluster_agent_id
        created_at
        default_resources_per_workspace_container
        default_runtime_class
        dns_zone
        enabled
        gitlab_workspaces_proxy_http_enabled
        gitlab_workspaces_proxy_namespace
        gitlab_workspaces_proxy_ssh_enabled
        id
        image_pull_secrets
        labels
        max_active_hours_before_stop
        max_resources_per_workspace
        max_stopped_hours_before_termination
        network_policy_egress
        network_policy_enabled
        project_id
        shared_namespace
        updated_at
        use_kubernetes_user_namespaces
        workspaces_per_user_quota
        workspaces_quota
      ]
      expect(config.attributes.keys.sort).to eq(known_attributes)
    end
  end

  it_behaves_like 'a model with paper trail configured' do
    let(:factory) { :workspaces_agent_config }
    let(:attributes_to_update) { { enabled: false } }
    let(:additional_properties) { {} }
  end
end
