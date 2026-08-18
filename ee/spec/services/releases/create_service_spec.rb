# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::CreateService, feature_category: :release_orchestration do
  let(:group) { create :group }
  let(:project) { create(:project, :repository, group: group) }
  let(:user) { create(:user, maintainer_of: project) }
  let(:tag_name) { 'v1.1.0' }
  let(:name) { 'Bionic Beaver' }
  let(:description) { 'Awesome release!' }
  let(:params) { { tag: tag_name, name: name, description: description } }
  let(:release) { Release.last }
  let(:service) { described_class.new(project, user, params_with_milestones) }

  describe 'group milestones' do
    context 'when a group milestone is passed' do
      let(:group_milestone) { create(:milestone, group: group, title: 'g1') }
      let(:params_with_milestones) { params.merge({ milestones: [group_milestone.title] }) }

      context 'when licenced' do
        before do
          stub_licensed_features(group_milestone_project_releases: true)
        end

        it 'adds the group milestone', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:success)
          expect(release.milestones).to match_array([group_milestone])
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

    context 'when a supergroup milestone is passed' do
      let(:group) { create(:group, parent: supergroup) }
      let(:supergroup) { create(:group) }
      let(:supergroup_milestone) { create(:milestone, group: supergroup, title: 'sg1') }
      let(:params_with_milestones) { params.merge({ milestones: [supergroup_milestone.title] }) }

      it 'raises an error', :aggregate_failures do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Milestone(s) not found: sg1")
        expect(release).to be_nil
      end
    end
  end

  describe 'audit events' do
    before do
      project.add_developer(user)
    end

    include_examples 'audit event logging' do
      let(:operation) { service.execute }
      let(:group_milestone) { create(:milestone, group: group, title: 'g1') }
      let(:params_with_milestones) { params.merge({ milestones: [group_milestone.title] }) }
      let(:event_type) { 'release_created' }
      let(:licensed_features_to_stub) { { group_milestone_project_releases: true } }
      # rubocop:disable RSpec/AnyInstanceOf -- It's not the next instance
      let(:fail_condition!) { allow_any_instance_of(Release).to receive(:save!).and_raise('save failed') }
      # rubocop:enable RSpec/AnyInstanceOf

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: project.id,
          entity_type: 'Project',
          details: {
            author_name: user.name,
            author_class: 'User',
            event_name: 'release_created',
            target_id: release.id,
            target_type: 'Release',
            target_details: release.name,
            custom_message: "Created release #{release.tag} with Milestone #{group_milestone.title}"
          }
        }
      end
    end
  end
end
