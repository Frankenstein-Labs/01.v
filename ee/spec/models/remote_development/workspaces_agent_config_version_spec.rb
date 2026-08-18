# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspacesAgentConfigVersion, feature_category: :workspaces do
  let_it_be(:workspaces_agent_config) { create(:workspaces_agent_config) }

  subject(:config_version) { workspaces_agent_config.versions.last }

  describe '#set_project_id' do
    it 'sets the project_id before saving' do
      expect(config_version.project_id).to eq(workspaces_agent_config.project_id)
    end
  end

  describe 'columns' do
    it { is_expected.to have_db_column(:project_id).of_type(:integer) }
    it { is_expected.to have_db_column(:created_at).of_type(:timestamptz) }
    it { is_expected.to have_db_column(:item_type).of_type(:text) }
    it { is_expected.to have_db_column(:item_id).of_type(:integer) }
    it { is_expected.to have_db_column(:event).of_type(:text) }
    it { is_expected.to have_db_column(:whodunnit).of_type(:text) }
    it { is_expected.to have_db_column(:object).of_type(:jsonb) }
    it { is_expected.to have_db_column(:object_changes).of_type(:jsonb) }
  end
end
