# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::Environments::ListService, feature_category: :continuous_delivery do
  describe '#execute' do
    def setup(organization: nil)
      user = create(:user)
      project = create(:project, developers: user, organization: organization)
      user.update!(ops_dashboard_projects: [project])

      [user, project]
    end

    before do
      stub_licensed_features(operations_dashboard: true)
    end

    it 'returns a list of projects' do
      user, project = setup

      projects_with_environments = described_class.new(user).execute

      expect(projects_with_environments).to eq([project])
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(operations_dashboard: false)
      end

      it 'returns an empty array' do
        user = create(:user)
        project = create(:project)
        project.add_developer(user)
        user.update!(ops_dashboard_projects: [project])

        projects_with_environments = described_class.new(user).execute

        expect(projects_with_environments).to eq([])
      end
    end

    context 'when organization is provided' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:other_organization) { create(:organization) }

      it 'returns only projects belonging to the organization' do
        user, project = setup(organization: organization)
        other_project = create(:project, :repository, organization: other_organization)
        other_project.add_developer(user)
        user.update!(ops_dashboard_projects: [project, other_project])

        projects_with_environments = described_class.new(user, organization: organization).execute

        expect(projects_with_environments).to contain_exactly(project)
      end

      it 'returns an empty list when no projects belong to the organization' do
        user, _project = setup(organization: other_organization)

        projects_with_environments = described_class.new(user, organization: organization).execute

        expect(projects_with_environments).to be_empty
      end
    end
  end
end
