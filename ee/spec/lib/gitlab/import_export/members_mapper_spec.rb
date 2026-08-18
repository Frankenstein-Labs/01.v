# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::MembersMapper, feature_category: :importers do
  describe '#map' do
    let(:user) { create(:admin) }
    let(:original_member) { create(:user) }
    let(:exported_members) do
      [{
        "id" => 2,
        "access_level" => 40,
        "source_id" => 14,
        "source_type" => "Project",
        "notification_level" => 3,
        "created_at" => "2016-03-11T10:21:44.822Z",
        "updated_at" => "2016-03-11T10:21:44.822Z",
        "created_by_id" => 1,
        "invite_email" => nil,
        "invite_token" => nil,
        "invite_accepted_at" => nil,
        "user" => {
          "id" => 99,
          "public_email" => original_member.email,
          "username" => 'test'
        },
        "user_id" => 19
      }]
    end

    let(:members_mapper) do
      described_class.new(
        exported_members: exported_members, user: user, importable: importable
      )
    end

    context 'when importable is Project with restricted membership' do
      let_it_be(:group) { create(:group, membership_lock: true) }
      let_it_be(:importable) { create(:project, :public, group: group) }

      it 'does not create any members' do
        expect { members_mapper }.not_to change { importable.reload.members.count }
      end
    end
  end
end
