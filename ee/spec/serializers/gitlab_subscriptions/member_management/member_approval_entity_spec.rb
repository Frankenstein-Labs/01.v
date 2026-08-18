# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MemberApprovalEntity,
  feature_category: :seat_cost_management do
  let(:group) { build_stubbed(:group) }
  let(:pending_member_approval) do
    build_stubbed(
      :gitlab_subscription_member_management_member_approval,
      member_namespace: group
    )
  end

  subject(:member_approval_entity) { described_class.new(pending_member_approval) }

  describe '#as_json' do
    it 'includes member approval attributes' do
      json_response = member_approval_entity.as_json

      expect(json_response.keys).to match_array([:created_at, :id, :new_access_level, :old_access_level,
        :requested_by, :reviewed_by, :source, :updated_at, :user])
      expect(json_response[:new_access_level].keys).to match_array([:integer_value, :member_role_id, :string_value])
      expect(json_response[:old_access_level].keys).to match_array([:integer_value, :string_value])
      expect(json_response[:source].keys).to match_array([:full_name, :id, :web_url])
      expect(json_response[:reviewed_by].keys).to match_array([:name, :web_url])
      expect(json_response[:requested_by].keys).to match_array([:name, :web_url])
    end
  end

  describe 'when assigning the member presenter' do
    it 'is only set once' do
      expect(::GitlabSubscriptions::MemberManagement::MemberApprovalPresenter).to receive(:new)
                                         .with(pending_member_approval)
                                         .and_call_original
                                         .once
      member_approval_entity.as_json
    end
  end
end
