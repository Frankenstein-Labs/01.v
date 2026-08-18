# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdeHelper, feature_category: :web_ide do
  describe '#ide_data' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:user) { project.creator }
    let_it_be(:fork_info) { { ide_path: '/test/ide/path' } }
    let_it_be(:workbench_secret) { 'test-workbench-secret' }

    let_it_be(:params) do
      {
        branch: 'master',
        path: 'foo/bar',
        merge_request_id: '1'
      }
    end

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:content_security_policy_nonce).and_return('test-csp-nonce')
      allow(helper).to receive(:new_session_path).and_return('test-sign-in-path')
    end

    it 'returns hash with code suggestions disabled' do
      expect(helper.ide_data(project: nil, fork_info: fork_info, workbench_secret: workbench_secret, params: params))
        .to include('code-suggestions-enabled' => '')
    end

    context 'when user can access code suggestions' do
      before do
        allow(user).to receive(:can?).with(:access_code_suggestions).and_return(true)
      end

      it 'returns hash with code suggestions enabled' do
        expect(
          helper.ide_data(project: project, fork_info: nil, workbench_secret: workbench_secret, params: params)
        ).to include('code-suggestions-enabled' => 'true')
      end
    end
  end
end
