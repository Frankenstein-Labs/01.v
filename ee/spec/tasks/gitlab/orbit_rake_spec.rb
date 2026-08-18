# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:orbit namespace rake tasks', :silence_stdout, feature_category: :knowledge_graph do
  before do
    Rake.application.rake_require 'tasks/gitlab/orbit'
  end

  describe 'gitlab:orbit:info' do
    it 'delegates to Analytics::RakeTask::Orbit.info' do
      expect(Analytics::RakeTask::Orbit).to receive(:info).with(
        name: 'gitlab:orbit:info',
        extended: nil,
        watch_interval: nil
      )

      run_rake_task('gitlab:orbit:info')
    end

    it 'passes watch_interval and extended arguments' do
      expect(Analytics::RakeTask::Orbit).to receive(:info).with(
        name: 'gitlab:orbit:info',
        extended: 'true',
        watch_interval: '5'
      )

      run_rake_task('gitlab:orbit:info', '5', 'true')
    end
  end
end
