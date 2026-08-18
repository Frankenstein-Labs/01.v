# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MemberApprovalSerializer,
  feature_category: :seat_cost_management do
  describe '#represent' do
    context 'when there are no member approvals' do
      it 'returns an empty array' do
        result = described_class.new.represent([])

        expect(result).to eq([])
      end
    end

    context 'when there are member approvals' do
      it 'returns member approval attributes' do
        group = build_stubbed(:group)
        pending_member_approval = build_stubbed(
          :gitlab_subscription_member_management_member_approval,
          member_namespace: group
        )
        pending_member_approvals = [pending_member_approval]

        result = described_class.new.represent(pending_member_approvals)

        expect(result.first.keys).to match_array([:created_at, :id, :new_access_level, :old_access_level,
          :requested_by, :reviewed_by, :source, :updated_at, :user])
        expect(result.first[:new_access_level].keys).to match_array([:integer_value, :member_role_id, :string_value])
        expect(result.first[:old_access_level].keys).to match_array([:integer_value, :string_value])
        expect(result.first[:source].keys).to match_array([:full_name, :id, :web_url])
        expect(result.first[:reviewed_by].keys).to match_array([:name, :web_url])
        expect(result.first[:requested_by].keys).to match_array([:name, :web_url])
      end
    end
  end
end
