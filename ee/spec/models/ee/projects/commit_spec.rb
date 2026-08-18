# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::Commit, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:commit)  { project.commit }

  it { is_expected.to include_module(::Ai::Model) }

  describe '#resource_parent' do
    it 'returns the project' do
      expect(commit.resource_parent).to eq(project)
    end
  end

  describe '#has_agent_session?' do
    using RSpec::Parameterized::TableSyntax

    let(:commit_for_test) { project.commit }
    let(:trailers_hash) { has_trailer ? { 'Duo-Session' => 'https://gitlab.com/session/123' } : {} }

    where(:feature_flag, :license, :duo_features, :setting_enabled, :has_trailer, :expected) do
      true  | true  | true  | true  | true  | true
      true  | true  | true  | true  | false | false
      false | true  | true  | true  | true  | false
      true  | false | true  | true  | true  | false
      true  | true  | false | true  | true  | false
      true  | true  | true  | false | true  | false
    end

    with_them do
      before do
        stub_feature_flags(dap_session_commit_tracking: feature_flag ? project : false)
        stub_licensed_features(ai_workflows: license)
        project.project_setting.update!(
          duo_features_enabled: duo_features,
          dap_session_tracking_enabled: setting_enabled
        )
        allow(commit_for_test).to receive(:trailers).and_return(trailers_hash)
      end

      it { expect(commit_for_test.has_agent_session?).to eq(expected) }
    end

    context 'when project is nil' do
      it 'returns false' do
        allow(commit_for_test).to receive(:project).and_return(nil)

        expect(commit_for_test.has_agent_session?).to be false
      end
    end

    context 'when trailers hash is empty (GraphQL ListCommits path)' do
      before do
        stub_licensed_features(ai_workflows: true)
        project.project_setting.update!(
          duo_features_enabled: true,
          dap_session_tracking_enabled: true
        )
        allow(commit_for_test).to receive(:trailers).and_return({})
      end

      context 'when safe_message contains the Duo-Session trailer' do
        before do
          allow(commit_for_test).to receive(:safe_message).and_return(
            "feat: implement feature\n\nSome description\n\nDuo-Session: https://gitlab.com/session/123\n"
          )
        end

        it 'returns true via regex fallback' do
          expect(commit_for_test.has_agent_session?).to be true
        end
      end

      context 'when safe_message does not contain the Duo-Session trailer' do
        before do
          allow(commit_for_test).to receive(:safe_message).and_return(
            "feat: implement feature\n\nSome description\n"
          )
        end

        it 'returns false' do
          expect(commit_for_test.has_agent_session?).to be false
        end
      end
    end

    context 'when trailers is nil' do
      before do
        stub_licensed_features(ai_workflows: true)
        project.project_setting.update!(
          duo_features_enabled: true,
          dap_session_tracking_enabled: true
        )
        allow(commit_for_test).to receive(:trailers).and_return(nil)
      end

      context 'when safe_message contains the Duo-Session trailer' do
        before do
          allow(commit_for_test).to receive(:safe_message).and_return(
            "fix: update config\n\nDuo-Session: https://gitlab.com/session/456\n"
          )
        end

        it 'returns true via regex fallback' do
          expect(commit_for_test.has_agent_session?).to be true
        end
      end

      context 'when safe_message is nil' do
        before do
          allow(commit_for_test).to receive(:safe_message).and_return(nil)
        end

        it 'returns false' do
          expect(commit_for_test.has_agent_session?).to be false
        end
      end

      context 'when safe_message does not contain the trailer' do
        before do
          allow(commit_for_test).to receive(:safe_message).and_return("fix: update config\n")
        end

        it 'returns false' do
          expect(commit_for_test.has_agent_session?).to be false
        end
      end
    end
  end
end
