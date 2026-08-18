# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupDestroyWorker, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let(:group) { create(:group, :deletion_scheduled) }
  let(:project) { create(:project, namespace: group) }
  let(:user) { create(:user, owner_of: group) }
  let(:admin) { create(:user, :admin, owner_of: group) }

  subject(:worker) { described_class.new }

  context 'with protective settings', :request_store do
    before do
      stub_ee_application_setting(
        default_project_deletion_protection: true
      )
    end

    where(:admin_mode_enabled, :user_is_admin, :should_delete) do
      true  | true   | true
      true  | false  | false
      false | true   | true
      false | false  | false
    end

    with_them do
      it do
        stub_application_setting(admin_mode: admin_mode_enabled)
        worker_user = user_is_admin ? admin : user

        group_id = group.id
        project_id = project.id

        worker.perform(group_id, worker_user.id)

        if should_delete
          expect { Group.find(group_id) }.to raise_error(ActiveRecord::RecordNotFound)
          expect { Project.find(project_id) }.to raise_error(ActiveRecord::RecordNotFound)
        else
          expect(Group.find(group_id)).to eq(group)
          expect(Project.find(project_id)).to eq(project)
        end
      end
    end
  end
end
