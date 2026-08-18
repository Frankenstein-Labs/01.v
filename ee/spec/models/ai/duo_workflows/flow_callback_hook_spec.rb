# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::FlowCallbackHook, feature_category: :duo_agent_platform do
  it_behaves_like 'a hook that does not get automatically disabled on failure' do
    let_it_be(:organization) { create(:organization) }
    let_it_be_with_reload(:hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }
    let(:hook_factory) { :duo_workflows_flow_callback_hook }
    let(:default_factory_arguments) { {} }

    def find_hooks
      described_class.all
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization_id) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:web_hook_logs) }
    it { is_expected.to belong_to(:organization) }
  end

  describe '.for_organization' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }
    let_it_be(:other_hook) { create(:duo_workflows_flow_callback_hook, organization: other_organization) }

    it 'returns only hooks for the given organization' do
      expect(described_class.for_organization(organization.id)).to contain_exactly(hook)
    end
  end

  describe '.recent_first' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:older_hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }
    let_it_be(:newer_hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }

    it 'orders hooks by id descending' do
      expect(described_class.recent_first).to eq([newer_hook, older_hook])
    end
  end

  describe '#parent' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }

    it 'returns the organization' do
      expect(hook.parent).to eq(organization)
    end
  end

  describe '#application_context' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:hook) { create(:duo_workflows_flow_callback_hook, organization: organization) }

    it 'includes the organization' do
      expect(hook.application_context).to include(organization: organization)
    end
  end

  describe '#pluralized_name' do
    let_it_be(:hook) { build(:duo_workflows_flow_callback_hook) }

    it 'returns a human-readable name' do
      expect(hook.pluralized_name).to eq('Duo flow callback hooks')
    end
  end

  describe 'secrets' do
    let_it_be(:organization) { create(:organization) }

    it 'never serializes the signing token' do
      hook = create(:duo_workflows_flow_callback_hook, :signing_token, organization: organization)

      expect(hook.serializable_hash).not_to have_key('signing_token')
    end

    it 'encrypts the url and token at rest' do
      hook = create(:duo_workflows_flow_callback_hook, :token, organization: organization)

      raw_attributes = hook.class.connection.select_one(
        hook.class.sanitize_sql(["SELECT encrypted_url, encrypted_token FROM web_hooks WHERE id = ?", hook.id])
      )

      expect(raw_attributes['encrypted_url']).not_to include(hook.url)
      expect(raw_attributes['encrypted_token']).not_to include(hook.token)
    end
  end
end
