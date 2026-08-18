# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::MergeRequestApprovalSetting, feature_category: :code_review_workflow do
  let(:setting) do
    ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
      value: true, locked: false, inherited_from: nil
    )
  end

  let(:setting_keys) do
    [
      :allow_author_approval,
      :allow_committer_approval,
      :allow_overrides_to_approver_list_per_merge_request,
      :retain_approvals_on_push,
      :selective_code_owner_removals,
      :require_password_to_approve,
      :require_reauthentication_to_approve
    ]
  end

  let(:approval_settings) { setting_keys.index_with { setting } }

  subject(:rendered) { Gitlab::Json.safe_parse(described_class.new(approval_settings).to_json) }

  it 'exposes correct attributes' do
    expect(rendered.keys.map(&:to_sym)).to match(setting_keys)
  end

  it 'serializes each setting with enforced_by_policy defaulting to false' do
    setting_keys.each do |key|
      expect(rendered[key.to_s]).to eq(
        'value' => true,
        'locked' => false,
        'inherited_from' => nil,
        'enforced_by_policy' => false
      )
    end
  end

  context 'when a setting is enforced by a policy' do
    let(:policy_enforced_setting) do
      ComplianceManagement::MergeRequestApprovalSettings::Setting.new(
        value: true, locked: false, inherited_from: nil, enforced_by_policy: true
      )
    end

    let(:approval_settings) do
      setting_keys.index_with { setting }.merge(
        allow_overrides_to_approver_list_per_merge_request: policy_enforced_setting
      )
    end

    it 'serializes enforced_by_policy: true for the affected setting' do
      expect(rendered['allow_overrides_to_approver_list_per_merge_request'])
        .to include('enforced_by_policy' => true)
    end
  end
end
