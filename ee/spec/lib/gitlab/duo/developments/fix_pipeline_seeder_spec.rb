# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::FixPipelineSeeder, feature_category: :duo_chat do
  describe 'GROUP_PATH' do
    it 'is set to gitlab-duo' do
      expect(described_class::GROUP_PATH).to eq('gitlab-duo')
    end
  end

  describe '.seed_pipelines' do
    let_it_be(:user) { create(:user, username: 'root') }
    let_it_be(:group) { create(:group, path: 'gitlab-duo') }
    let_it_be(:project) { create(:project, namespace: group, path: 'fix_pipeline_evaluation') }

    before do
      stub_env('GDK_PAT', 'test-gdk-token')
      stub_env('GITLAB_COM_PAT', 'test-gitlab-token')

      allow(described_class).to receive(:fetch_dataset_from_langsmith).and_return([])
      allow(described_class).to receive(:import_gitlab_project)
      allow(described_class).to receive(:create_evaluation_yaml)
    end

    it 'finds the root user by username' do
      expect(User).to receive(:find_by_username).with('root').and_return(user)

      described_class.seed_pipelines
    end

    context 'when root user does not exist' do
      before do
        allow(User).to receive(:find_by_username).with('root').and_return(nil)
      end

      it 'aborts with an error message' do
        expect { described_class.seed_pipelines }.to raise_error(SystemExit)
      end
    end

    context 'when GDK_PAT is not set' do
      before do
        stub_env('GDK_PAT', nil)
      end

      it 'aborts with an error message' do
        expect { described_class.seed_pipelines }.to raise_error(SystemExit)
      end
    end

    context 'when GITLAB_COM_PAT is not set' do
      before do
        stub_env('GITLAB_COM_PAT', nil)
      end

      it 'aborts with an error message' do
        expect { described_class.seed_pipelines }.to raise_error(SystemExit)
      end
    end
  end
end
