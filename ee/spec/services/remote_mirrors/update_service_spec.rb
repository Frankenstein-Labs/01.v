# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteMirrors::UpdateService, feature_category: :source_code_management do
  subject(:service) { described_class.new(project, user, params) }

  let_it_be(:project) { create(:project, :empty_repo) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let!(:remote_mirror) { create(:remote_mirror, project: project) }

  let(:params) do
    {
      mirror_branch_regex: mirror_branch_regex,
      only_protected_branches: only_protected_branches
    }
  end

  let(:only_protected_branches) { false }
  let(:mirror_branch_regex) { nil }

  describe '#execute', :aggregate_failures do
    subject(:execute) { service.execute(remote_mirror) }

    let(:updated_remote_mirror) { execute.payload[:remote_mirror] }

    context 'when remote mirror has `mirror_branch_regex` value defined' do
      before do
        remote_mirror.update!(mirror_branch_regex: 'regex')
      end

      context 'when only protected branches value is set' do
        let(:only_protected_branches) { true }

        it 'removes previous `mirror_branch_regex` value' do
          is_expected.to be_success

          expect(updated_remote_mirror).to have_attributes(
            only_protected_branches: true,
            mirror_branch_regex: nil
          )
        end
      end
    end

    context 'when remote mirror has `only_protected_branches` value defined' do
      before do
        remote_mirror.update!(only_protected_branches: true)
      end

      context 'when `mirror_branch_regex` value is set' do
        let(:mirror_branch_regex) { 'regex' }

        it 'disables `only_protected_branches`' do
          is_expected.to be_success

          expect(updated_remote_mirror).to have_attributes(
            only_protected_branches: false,
            mirror_branch_regex: 'regex'
          )
        end
      end
    end

    context 'when both mirror_branch_regex and only_protected_branches are provided' do
      let(:mirror_branch_regex) { 'regex' }
      let(:only_protected_branches) { true }

      it 'updates the push mirror with only "mirror_branch_regex" value' do
        is_expected.to be_success

        expect(updated_remote_mirror).to have_attributes(
          mirror_branch_regex: mirror_branch_regex,
          only_protected_branches: false
        )
      end
    end
  end
end
