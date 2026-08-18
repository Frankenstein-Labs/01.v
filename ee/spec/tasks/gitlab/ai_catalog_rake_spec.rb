# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:ai_catalog tasks', :silence_stdout, feature_category: :workflow_catalog do
  before do
    Rake.application.rake_require 'tasks/gitlab/ai_catalog'
  end

  describe 'ai_catalog:seed_external_agents' do
    subject(:run_task) { run_rake_task 'gitlab:ai_catalog:seed_external_agents' }

    it 'calls Gitlab::Ai::Catalog::ThirdPartyFlows::Seeder.run!' do
      expect(Gitlab::Ai::Catalog::ThirdPartyFlows::Seeder).to receive(:run!)

      run_task
    end
  end
end
