# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::UpdateService, feature_category: :release_orchestration do
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, group: group) }
  let(:user) { create(:user) }
  let(:params) { { tag: tag_name } }
  let!(:release) { create(:release, project: project, tag: tag_name) }
  let(:tag_name) { 'v1.1.0' }
  let(:service) { described_class.new(project, user, params_with_milestones) }

  before do
    project.add_developer(user)
  end

  describe 'group milestones' do
    context 'when a group milestone is passed' do
      let(:group_milestone) { create(:milestone, group: group, title: 'g1') }
      let(:params_with_milestones) { params.merge({ milestones: [group_milestone.title] }) }

      context 'when there is no project milestone' do
        context 'when licenced' do
          before do
            stub_licensed_features(group_milestone_project_releases: true)
          end

          it 'adds the group milestone', :aggregate_failures do
            result = service.execute
            release.reload

            expect(release.milestones).to match_array([group_milestone])
            expect(result[:milestones_updated]).to be_truthy
          end
        end

        context 'when unlicensed' do
          it 'returns an error', :aggregate_failures do
            result = service.execute

            expect(result[:status]).to eq(:error)
            expect(result[:milestones_updated]).to be_falsy
            expect(result[:message]).to match(/None of the group milestones have the same project as the release/)
          end
        end
      end

      context 'when there is an existing project milestone' do
        let(:project_milestone) { create(:milestone, project: project, title: 'p1') }

        before do
          release.milestones << project_milestone
        end

        context 'when licenced' do
          before do
            stub_licensed_features(group_milestone_project_releases: true)
          end

          it 'replaces the project milestone with the group milestone', :aggregate_failures do
            result = service.execute
            release.reload

            expect(release.milestones).to match_array([group_milestone])
            expect(result[:milestones_updated]).to be_truthy
          end
        end

        context 'when unlicensed' do
          it 'returns an error', :aggregate_failures do
            result = service.execute

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to match(/None of the group milestones have the same project as the release/)
          end
        end
      end

      context 'when an empty milestone array is passed' do
        let(:project_milestone) { create(:milestone, project: project, title: 'p1') }
        let(:params_with_milestones) { params.merge({ milestones: [] }) }

        before do
          release.milestones << project_milestone
        end

        it 'clears the milestone array', :aggregate_failures do
          result = service.execute
          release.reload

          expect(release.milestones).to be_empty
          expect(result[:milestones_updated]).to be_truthy
        end
      end

      context 'when a supergroup milestone is passed' do
        let(:group) { create(:group, parent: supergroup) }
        let(:supergroup) { create(:group) }
        let(:supergroup_milestone) { create(:milestone, group: supergroup, title: 'sg1') }
        let(:params_with_milestones) { params.merge({ milestones: [supergroup_milestone.title] }) }

        it 'ignores the milestone' do
          service.execute
          release.reload

          expect(release.milestones).to be_empty
        end
      end
    end
  end

  describe 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { service.execute }
      let(:params_with_milestones) { params.merge({ name: "Updated name" }) }
      let(:event_type) { 'release_updated' }
      let(:licensed_features_to_stub) { { group_milestone_project_releases: true } }
      # rubocop:disable RSpec/AnyInstanceOf -- It's not the next instance
      let(:fail_condition!) { allow_any_instance_of(Release).to receive(:update).and_return(false) }
      # rubocop:enable RSpec/AnyInstanceOf

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: project.id,
          entity_type: 'Project',
          details: {
            author_name: user.name,
            author_class: 'User',
            event_name: "release_updated",
            target_id: release.id,
            target_type: 'Release',
            target_details: "Updated name",
            custom_message: "Updated release #{release.tag}"
          }
        }
      end
    end
  end
end
