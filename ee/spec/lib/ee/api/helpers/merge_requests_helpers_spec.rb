# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::MergeRequestsHelpers, feature_category: :code_review_workflow do
  let(:helper_class) do
    Class.new do
      include API::Helpers::MergeRequestsHelpers

      attr_accessor :access_token

      def initialize(token = nil)
        @access_token = token
      end
    end
  end

  let(:helper) { helper_class.new(access_token) }
  let(:access_token) { nil }

  describe '#filter_diffs_for_mcp' do
    let_it_be(:project) { create(:project) }
    let(:diff_rb) { instance_double(Gitlab::Git::Diff, new_path: 'app/models/user.rb', old_path: 'app/models/user.rb') }
    let(:diff_md) { instance_double(Gitlab::Git::Diff, new_path: 'README.md', old_path: 'README.md') }
    let(:diff_yml) do
      instance_double(Gitlab::Git::Diff, new_path: 'config/database.yml', old_path: 'config/database.yml')
    end

    let(:diffs) { [diff_rb, diff_md, diff_yml] }

    subject(:filter_diffs_for_mcp) { helper.filter_diffs_for_mcp(diffs, project) }

    context 'when not an MCP request' do
      let(:access_token) { create(:oauth_access_token, scopes: [:api]) }

      it 'returns all diffs unfiltered' do
        is_expected.to match_array(diffs)
      end

      it 'does not call FileExclusionService' do
        expect(Ai::FileExclusionService).not_to receive(:new)
        filter_diffs_for_mcp
      end
    end

    context 'when project is nil' do
      let(:project) { nil }
      let(:access_token) { create(:oauth_access_token, scopes: [:mcp]) }

      it 'returns all diffs unfiltered' do
        is_expected.to match_array(diffs)
      end
    end

    context 'when it is an MCP request' do
      let(:access_token) { create(:oauth_access_token, scopes: [:mcp]) }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: exclusion_rules }
        )
      end

      context 'with no exclusion rules' do
        let(:exclusion_rules) { [] }

        it 'returns all diffs' do
          is_expected.to match_array(diffs)
        end
      end

      context 'with exclusion rules matching some files' do
        let(:exclusion_rules) { ['*.md'] }

        it 'filters out excluded files' do
          is_expected.to match_array([diff_rb, diff_yml])
        end
      end

      context 'with exclusion rules matching all files' do
        let(:exclusion_rules) { ['*', '**/*'] }

        it 'returns empty array' do
          is_expected.to be_empty
        end
      end

      context 'when diffs array is empty' do
        let(:diffs) { [] }
        let(:exclusion_rules) { ['*.md'] }

        it 'returns empty array' do
          is_expected.to be_empty
        end
      end

      context 'when FileExclusionService returns error' do
        let(:exclusion_rules) { ['*.md'] }

        before do
          allow_next_instance_of(Ai::FileExclusionService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Test error')
            )
          end
        end

        it 'returns all diffs unfiltered' do
          is_expected.to match_array(diffs)
        end
      end

      context 'with diffs that have nil paths' do
        let(:diff_nil) { instance_double(Gitlab::Git::Diff, new_path: nil, old_path: nil) }
        let(:diffs) { [diff_rb, diff_nil] }
        let(:exclusion_rules) { ['*.rb'] }

        it 'handles nil paths gracefully' do
          is_expected.to match_array([diff_nil]) # Only the one with nil paths remains
        end
      end
    end
  end
end
