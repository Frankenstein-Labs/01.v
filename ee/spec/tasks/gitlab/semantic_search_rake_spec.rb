# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:semantic_search namespace rake tasks', :silence_stdout, feature_category: :global_search do
  before do
    Rake.application.rake_require 'tasks/gitlab/semantic_search'
  end

  describe 'gitlab:semantic_search:code:info' do
    it 'calls Search::RakeTask::SemanticSearch.info with task name and watch_interval' do
      expect(Search::RakeTask::SemanticSearch).to receive(:info).with(
        name: 'gitlab:semantic_search:code:info',
        watch_interval: nil
      )

      run_rake_task('gitlab:semantic_search:code:info')
    end

    it 'passes watch_interval argument when provided' do
      expect(Search::RakeTask::SemanticSearch).to receive(:info).with(
        name: 'gitlab:semantic_search:code:info',
        watch_interval: '10'
      )

      run_rake_task('gitlab:semantic_search:code:info', '10')
    end
  end
end
