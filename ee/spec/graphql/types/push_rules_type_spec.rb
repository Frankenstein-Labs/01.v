# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PushRules'], feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let(:expected_fields) do
    %i[
      deny_delete_tag
      member_check
      prevent_secrets
      commit_message_regex
      commit_message_negative_regex
      branch_name_regex
      author_email_regex
      file_name_regex
      max_file_size
      commit_committer_check
      commit_committer_name_check
      reject_unsigned_commits
      reject_non_dco_commits
    ]
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:push_rule) do
    create(:push_rule,
      project: project,
      deny_delete_tag: true,
      member_check: true,
      prevent_secrets: true,
      commit_message_regex: 'Fixed \d+\..*',
      commit_message_negative_regex: 'WIP:.*',
      branch_name_regex: '(feature|hotfix)/.*',
      author_email_regex: '@example\.com$',
      file_name_regex: '\.(exe|jar)$',
      max_file_size: 100,
      commit_committer_check: true,
      commit_committer_name_check: true,
      reject_unsigned_commits: true,
      reject_non_dco_commits: true
    )
  end

  before_all do
    project.add_developer(user)
  end

  specify do
    expect(described_class.graphql_name).to eq('PushRules')
    expect(described_class).to require_graphql_authorizations(:read_project)
    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe 'field resolution' do
    it 'resolves basic fields correctly' do
      expect(resolve_field(:deny_delete_tag, push_rule, current_user: user)).to be(true)
      expect(resolve_field(:member_check, push_rule, current_user: user)).to be(true)
      expect(resolve_field(:prevent_secrets, push_rule, current_user: user)).to be(true)
      expect(resolve_field(:commit_message_regex, push_rule, current_user: user)).to eq('Fixed \d+\..*')
      expect(resolve_field(:commit_message_negative_regex, push_rule, current_user: user)).to eq('WIP:.*')
      expect(resolve_field(:branch_name_regex, push_rule, current_user: user)).to eq('(feature|hotfix)/.*')
      expect(resolve_field(:author_email_regex, push_rule, current_user: user)).to eq('@example\.com$')
      expect(resolve_field(:file_name_regex, push_rule, current_user: user)).to eq('\.(exe|jar)$')
      expect(resolve_field(:max_file_size, push_rule, current_user: user)).to eq(100)
    end

    describe 'feature-gated fields' do
      using RSpec::Parameterized::TableSyntax

      where(:field, :feature) do
        :reject_unsigned_commits     | :reject_unsigned_commits
        :commit_committer_check      | :commit_committer_check
        :commit_committer_name_check | :commit_committer_name_check
        :reject_non_dco_commits      | :reject_non_dco_commits
      end

      with_them do
        it 'returns the value when feature is available' do
          allow(push_rule).to receive(:available?).with(feature).and_return(true)

          expect(resolve_field(field, push_rule, current_user: user)).to be(true)
        end

        it 'returns false when feature is not available' do
          allow(push_rule).to receive(:available?).with(feature).and_return(false)

          expect(resolve_field(field, push_rule, current_user: user)).to be(false)
        end
      end
    end
  end
end
