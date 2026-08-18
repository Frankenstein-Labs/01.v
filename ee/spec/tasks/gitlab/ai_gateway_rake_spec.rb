# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:ai_gateway rake tasks', feature_category: :duo_agent_platform do
  before do
    Rake.application.rake_require 'tasks/gitlab/ai_gateway'
    Rake::Task.define_task(:gitlab_environment)
  end

  describe 'gitlab:ai_gateway:install' do
    let(:task) { Rake::Task['gitlab:ai_gateway:install'] }
    let(:path) { '/tmp/tests/gitlab-ai-gateway' }

    before do
      task.reenable
    end

    context 'when path argument is provided' do
      it 'calls Utils.install! with the provided path' do
        expect(::Tasks::Gitlab::AiGateway::Utils).to receive(:install!).with(path: path)

        task.invoke(path)
      end
    end

    context 'when path argument is not provided' do
      it 'calls Utils.install! with no arguments' do
        expect(::Tasks::Gitlab::AiGateway::Utils).to receive(:install!)

        task.invoke
      end
    end
  end
end
