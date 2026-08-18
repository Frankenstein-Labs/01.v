# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdateStatisticsService, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let(:service) { described_class.new(project, nil, statistics: statistics) }
  let(:statistics) { %w[repository_size] }

  describe '#execute' do
    context 'with a non-existing project' do
      let(:project) { nil }

      it_behaves_like 'does not record an onboarding progress action' do
        subject { service.execute }
      end
    end

    context 'with an existing project with project repository' do
      subject { service.execute }

      context 'when the repository is empty' do
        let_it_be(:project, freeze: false) { create(:project) }

        it_behaves_like 'does not record an onboarding progress action'
      end

      context 'when the repository has more than one commit or more than one branch' do
        let_it_be(:project, freeze: false) { create(:project, :readme) }

        where(:commit_count, :branch_count) do
          2 | 1
          1 | 2
          2 | 2
        end

        with_them do
          before do
            allow(project.repository).to receive_messages(commit_count: commit_count, branch_count: branch_count)
          end

          it_behaves_like 'records an onboarding progress action', :code_added do
            let(:namespace) { project.namespace }
          end
        end

        context 'when project is the initial project created from registration, which only has a readme file' do
          it_behaves_like 'does not record an onboarding progress action'
        end
      end

      context 'with project created from templates or imported where commit and branch count are no more than 1' do
        let_it_be(:project, freeze: false) do
          create(:project, :custom_repo, files: { 'test.txt' => 'test', 'README.md' => 'test' })
        end

        it_behaves_like 'records an onboarding progress action', :code_added do
          let(:namespace) { project.namespace }
        end
      end
    end
  end
end
