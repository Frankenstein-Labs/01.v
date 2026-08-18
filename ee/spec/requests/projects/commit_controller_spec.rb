# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::CommitController, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository, :public, :in_group) }

  describe 'signed commit verification' do
    context 'with SSH signature' do
      let(:commit) { project.commit('7b5160f9bb23a3d58a0accdbe89da13b96b1ece9') }

      context 'when the commit has been signed by a certificate' do
        def badge_content(rendered)
          page = Nokogiri::HTML.parse(rendered)
          badge = page.at('.signature-badge')

          [
            badge.attributes['data-title'].value,
            badge.attributes['data-content'].value
          ]
        end

        it 'renders verified badge' do
          create(:ssh_signature, commit_sha: commit.sha, project: project, verification_status: :verified_ca)

          get project_commit_url(project, commit)

          title, content = badge_content(response.body)

          expect(content).to include('SSH key fingerprint')
          expect(content).to include(commit.signature.key_fingerprint_sha256)

          expect(title).to include(
            'This commit was signed with a certificate issued by top-level group Certificate Authority (CA)'
          )
        end
      end
    end
  end
end
