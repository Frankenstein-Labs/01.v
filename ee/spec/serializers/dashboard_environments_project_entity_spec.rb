# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DashboardEnvironmentsProjectEntity, feature_category: :continuous_delivery do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- requires persisted records for policy evaluation and AR association queries
  describe '.as_json' do
    it 'includes project attributes and returns environments' do
      user = create(:user)
      project = create(:project)
      project.add_developer(user)
      create(:environment, project: project, name: 'production')
      entity_request = EntityRequest.new(current_user: user)

      result = described_class.new(project, request: entity_request).as_json

      expect(result.keys.sort).to eq([:avatar_url, :environments, :id, :name, :namespace, :remove_path, :web_url])
      expect(result[:environments].length).to eq(1)
      expect(result[:environments].first[:name]).to eq('production')
    end

    context 'when environments feature is disabled' do
      it 'returns an empty environments list' do
        user = create(:user)
        project = create(:project)
        project.add_developer(user)
        project.project_feature.update!(environments_access_level: ProjectFeature::DISABLED)
        create(:environment, project: project, name: 'production')
        entity_request = EntityRequest.new(current_user: user)

        result = described_class.new(project, request: entity_request).as_json

        expect(result[:environments]).to be_empty
      end
    end
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate
end
