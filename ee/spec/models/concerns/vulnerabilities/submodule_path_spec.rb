# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::SubmodulePath, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:sha) { 'abc123def456abc123def456abc123def456abc123' }
  let(:file_path) { 'my-submodule/src/vulnerable.rb' }
  let(:submodule_path) { 'my-submodule' }
  let(:relative_file) { 'src/vulnerable.rb' }
  let(:submodule_commit_id) { 'deadbeef1234deadbeef1234deadbeef12345678' }
  let(:submodule_entry) { instance_double(Gitlab::Git::Blob, id: submodule_commit_id) }
  let(:repository) { project.repository }
  let(:finding) { build_stubbed(:vulnerabilities_finding, project: project) }

  subject(:includer) { Vulnerabilities::FindingPresenter.new(finding) }

  describe '#resolve_submodule_blob_url' do
    subject(:result) { includer.send(:resolve_submodule_blob_url, project, sha, file_path) }

    context 'when sha is blank' do
      let(:sha) { nil }

      it { is_expected.to be_nil }
    end

    context 'when file_path is blank' do
      let(:file_path) { '' }

      it { is_expected.to be_nil }
    end

    context 'when repository has no submodules' do
      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return({})
      end

      it { is_expected.to be_nil }
    end

    context 'when submodule_urls_for returns nil' do
      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(nil)
      end

      it { is_expected.to be_nil }
    end

    context 'when Gitaly raises NoRepository (repository does not exist)' do
      before do
        allow(repository).to receive(:submodule_urls_for).with(sha)
          .and_raise(Gitlab::Git::Repository::NoRepository)
      end

      it 'rescues and returns nil' do
        is_expected.to be_nil
      end
    end

    context 'when Gitaly raises CommandError (e.g. UNAVAILABLE or INTERNAL gRPC status)' do
      before do
        allow(repository).to receive(:submodule_urls_for).with(sha)
          .and_raise(Gitlab::Git::CommandError)
      end

      it 'rescues and returns nil' do
        is_expected.to be_nil
      end
    end

    context 'when file path does not start with any submodule path' do
      let(:file_path) { 'top-level/src/file.rb' }

      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(
          { 'other-submodule' => 'https://github.com/org/other.git' }
        )
      end

      it { is_expected.to be_nil }
    end

    context 'when file path matches a submodule prefix but gitlink entry is missing' do
      let(:submodule_url) { "#{Gitlab.config.gitlab.url}/ns/sub-project.git" }

      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(
          { submodule_path => submodule_url }
        )
        allow(repository).to receive(:blob_at).with(sha, submodule_path).and_return(nil)
      end

      it 'returns nil when the gitlink tree entry cannot be found' do
        is_expected.to be_nil
      end
    end

    context 'when the submodule URL is an unknown external host' do
      let(:submodule_url) { 'https://unknown-host.example.com/org/repo.git' }

      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(
          { submodule_path => submodule_url }
        )
        allow(repository).to receive(:blob_at).with(sha, submodule_path).and_return(submodule_entry)
      end

      # build_submodule_blob_url returns nil (tree_url is nil for unknown hosts), so the
      # each loop exhausts without returning and compute_submodule_blob_url returns nil.
      it 'returns nil and falls through the each loop (url is nil, covers line 55 branch)' do
        is_expected.to be_nil
      end
    end

    context 'when the file is inside a submodule on the same GitLab instance' do
      let(:submodule_url) { "#{Gitlab.config.gitlab.url}/ns/sub-project.git" }

      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(
          { submodule_path => submodule_url }
        )
        allow(repository).to receive(:blob_at).with(sha, submodule_path).and_return(submodule_entry)
      end

      it 'returns a blob URL pointing into the submodule project' do
        expect(result).to eq("/ns/sub-project/-/blob/#{submodule_commit_id}/#{relative_file}")
      end
    end

    context 'when the same project+sha is resolved twice' do
      let(:submodule_url) { "#{Gitlab.config.gitlab.url}/ns/sub-project.git" }

      before do
        allow(repository).to receive(:submodule_urls_for).with(sha).and_return(
          { submodule_path => submodule_url }
        ).once
        allow(repository).to receive(:blob_at).with(sha, submodule_path).and_return(submodule_entry)
      end

      it 'calls submodule_urls_for only once thanks to request-store caching' do
        Gitlab::SafeRequestStore.ensure_request_store do
          includer.send(:resolve_submodule_blob_url, project, sha, file_path)
          expect(includer.send(:resolve_submodule_blob_url, project, sha, file_path))
            .to eq("/ns/sub-project/-/blob/#{submodule_commit_id}/#{relative_file}")
        end
      end
    end
  end

  describe '#build_submodule_blob_url' do
    subject(:result) do
      includer.send(:build_submodule_blob_url, submodule_url, submodule_commit_id, relative_file, project)
    end

    context 'when tree_url uses GitLab-style /-/tree/ path (same instance)' do
      let(:submodule_url) { "#{Gitlab.config.gitlab.url}/ns/sub-project.git" }

      it 'rewrites /-/tree/<sha> to /-/blob/<sha>/<file>' do
        expect(result).to eq("/ns/sub-project/-/blob/#{submodule_commit_id}/#{relative_file}")
      end
    end

    context 'when tree_url uses GitHub-style /tree/ path' do
      let(:submodule_url) { 'https://github.com/org/repo.git' }

      it 'rewrites /tree/<sha> to /blob/<sha>/<file>' do
        expect(result).to eq("https://github.com/org/repo/blob/#{submodule_commit_id}/#{relative_file}")
      end
    end

    context 'when SubmoduleHelper returns nil tree_url (unknown external host)' do
      let(:submodule_url) { 'https://unknown-host.example.com/org/repo.git' }

      it { is_expected.to be_nil }
    end

    context 'when tree_url does not contain a /tree/<sha> segment (e.g. a GitHub Gist submodule)' do
      # gist_github_com_tree_links returns "https://gist.github.com/ns/project/<sha>"
      # with no /tree/ segment, so neither regex in build_submodule_blob_url matches and
      # the method returns nil
      let(:submodule_url) { 'https://gist.github.com/some-user/abc123def456.git' }

      it 'returns nil because the gist tree_url format has no /tree/ segment to rewrite' do
        is_expected.to be_nil
      end
    end
  end
end
