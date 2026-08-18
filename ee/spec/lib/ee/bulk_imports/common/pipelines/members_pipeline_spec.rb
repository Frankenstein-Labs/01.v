# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Common::Pipelines::MembersPipeline, feature_category: :importers do
  let_it_be(:user_running_import) { create(:user) }
  let_it_be(:bulk_import, freeze: false) { create(:bulk_import, :with_configuration, user: user_running_import) }
  let_it_be(:member_target_user) { create(:user, email: 'user@example.com') }
  let_it_be(:member_data, freeze: false) do
    {
      user_id: member_target_user.id,
      created_by_id: user_running_import.id,
      access_level: 30,
      created_at: '2020-01-01T00:00:00Z',
      updated_at: '2020-01-01T00:00:00Z',
      expires_at: nil
    }
  end

  let(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let(:context) { BulkImports::Pipeline::Context.new(tracker) }
  let(:members) { portable.members.map { |m| m.slice(:user_id, :access_level) } }
  let_it_be_with_reload(:parent) { create(:group, membership_lock: false) }
  let_it_be_with_reload(:portable) { create(:project, group: parent) }
  let(:entity) { create(:bulk_import_entity, :project_entity, project: portable, bulk_import: bulk_import) }

  let(:member_data_with_source_user) do
    {
      source_user: build(:import_source_user),
      access_level: 30,
      expires_at: '2020-01-01T00:00:00Z',
      group: nil,
      project: portable
    }
  end

  subject(:pipeline) { described_class.new(context) }

  before do
    allow(pipeline).to receive(:set_source_objects_counter)
  end

  describe '#load', :clean_gitlab_redis_shared_state do
    context 'when importing a project into a group with open membership' do
      before do
        parent.update!(membership_lock: false)
      end

      it 'creates a new membership' do
        expect { pipeline.load(context, member_data) }.to change { portable.members.count }.from(0).to(1)
      end

      it 'creates a placeholder user membership' do
        allow_next_instance_of(Import::PlaceholderMemberships::CreateService) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        pipeline.load(context, member_data_with_source_user)
      end
    end

    context 'when importing a project into a group with locked membership' do
      before do
        parent.update!(membership_lock: true)
      end

      it 'does not create a new membership' do
        expect { pipeline.load(context, member_data) }.not_to change { portable.members.count }
      end

      it 'does not create a placeholder user membership' do
        expect(Import::PlaceholderMemberships::CreateService).not_to receive(:new)

        pipeline.load(context, member_data_with_source_user)
      end
    end
  end
end
