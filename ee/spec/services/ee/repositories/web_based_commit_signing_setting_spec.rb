# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Repositories::WebBasedCommitSigningSetting, feature_category: :source_code_management do
  describe '#sign_commits?' do
    subject { described_class.new(repository).sign_commits? }

    using RSpec::Parameterized::TableSyntax
    context 'when repository does not belong to a group or a user' do
      let_it_be_with_refind(:personal_snippet) { create(:personal_snippet, :repository) }
      let(:user) { personal_snippet.author }
      let(:repository) { personal_snippet.repository }

      where(:repositories_web_based_commit_signing, :expected_sign) do
        true  | false
        false | true
      end

      before do
        stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
      end

      with_them do
        it { is_expected.to eq(expected_sign) }
      end
    end

    context 'when there are web_based_commit_signing_enabled settings' do
      where(
        :repositories_web_based_commit_signing,
        :web_based_commit_signing_enabled,
        :expected_sign) do
        true  | false | false
        true  | true  | true
        false | false | true
        false | true  | true
      end

      with_them do
        before do
          stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
        end

        context 'when repository belongs to a project' do
          let_it_be_with_refind(:project) { create(:project, :repository) }
          let(:user) { project.owner }
          let(:repository) { project.repository }

          before do
            project.web_based_commit_signing_enabled = web_based_commit_signing_enabled
          end

          it { is_expected.to eq(expected_sign) }
        end

        context 'when repository belongs to a group' do
          let_it_be_with_refind(:group_wiki) { create(:group_wiki_repository) }

          let(:group) { group_wiki.group }
          let(:user) { create(:user, owner_of: group) }
          let(:repository) { group_wiki.repository }
          let(:target_sha) { Gitlab::Git::SHA1_BLANK_SHA }

          before do
            group.namespace_settings.update!(web_based_commit_signing_enabled: web_based_commit_signing_enabled)
          end

          it { is_expected.to eq(expected_sign) }
        end
      end
    end
  end
end
