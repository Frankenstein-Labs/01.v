# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupHook, feature_category: :webhooks do
  include_examples 'a hook that gets automatically disabled on failure' do
    let_it_be(:group) { create(:group) }

    let(:hook) { build(:group_hook, group: group) }
    let(:hook_factory) { :group_hook }
    let(:default_factory_arguments) { { group: group } }

    def find_hooks
      group.hooks
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to :group }
    it { is_expected.to have_many(:web_hook_logs) }
  end

  describe '#destroy' do
    it 'does not cascade to web_hook_logs' do
      web_hook = create(:group_hook)
      create_list(:web_hook_log, 3, web_hook: web_hook)

      expect { web_hook.destroy! }.not_to change { web_hook.web_hook_logs.count }
    end
  end

  it_behaves_like 'includes Limitable concern' do
    subject { build(:group_hook) }
  end

  describe '#parent' do
    it 'returns the associated group' do
      group = build(:group)
      hook = build(:group_hook, group: group)

      expect(hook.parent).to eq(group)
    end
  end

  describe '#application_context' do
    let_it_be(:hook) { build(:group_hook) }

    it 'includes the type, group, and organization' do
      expect(hook.application_context).to eq(
        related_class: 'GroupHook',
        namespace: hook.group,
        organization: hook.group.organization
      )
    end
  end
end
