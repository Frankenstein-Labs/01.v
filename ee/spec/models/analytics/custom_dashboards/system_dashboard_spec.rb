# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::SystemDashboard, feature_category: :custom_dashboards_foundation do
  let(:config) do
    {
      'title' => 'GitLab Duo and SDLC trends',
      'description' => 'Visualize Duo usage and development trends.',
      'version' => '2',
      'panels' => []
    }
  end

  subject(:dashboard) { described_class.new(slug: 'gitlab_duo', config: config) }

  describe '#id' do
    it 'returns a prefixed slug' do
      expect(dashboard.id).to eq('gitlab:dashboard:gitlab_duo')
    end
  end

  describe '#name' do
    it 'returns the title from config' do
      expect(dashboard.name).to eq('GitLab Duo and SDLC trends')
    end
  end

  describe '#description' do
    it 'returns the description from config' do
      expect(dashboard.description).to eq('Visualize Duo usage and development trends.')
    end

    context 'when description is not present in config' do
      let(:config) { { 'title' => 'Test', 'version' => '2', 'panels' => [] } }

      it 'returns nil' do
        expect(dashboard.description).to be_nil
      end
    end
  end

  describe '#system?' do
    it 'returns true' do
      expect(dashboard.system?).to be(true)
    end
  end

  describe '#readonly?' do
    it 'returns true' do
      expect(dashboard.readonly?).to be(true)
    end
  end

  describe '#persisted?' do
    it 'returns true' do
      expect(dashboard.persisted?).to be(true)
    end
  end

  describe '#created_at' do
    it 'returns nil' do
      expect(dashboard.created_at).to be_nil
    end
  end
end
