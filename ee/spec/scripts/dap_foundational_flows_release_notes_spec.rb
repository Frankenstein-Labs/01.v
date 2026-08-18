# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../scripts/dap_foundational_flows_release_notes'
require 'webmock/rspec'

RSpec.describe DapFoundationalFlowsReleaseNotes, feature_category: :duo_agent_platform do
  include StubENV

  let(:aigw_token) { 'aigw-token' }
  let(:dap_token) { 'dap-token' }
  let(:dap_project_id) { '12345' }
  let(:commit_tag) { 'v18.10.0-ee' }
  let(:api_base) { 'https://gitlab.com/api/v4' }
  let(:aigw_project_id) { described_class::AIGW_PROJECT_ID }

  before do
    stub_env('AIGW_TAGGING_ACCESS_TOKEN', aigw_token)
    stub_env('DAP_RELEASE_NOTES_TOKEN', dap_token)
    stub_env('DAP_PROJECT_ID', dap_project_id)
    stub_env('CI_COMMIT_TAG', commit_tag)
  end

  describe '#initialize' do
    context 'when AIGW_TAGGING_ACCESS_TOKEN is missing' do
      before do
        stub_env('AIGW_TAGGING_ACCESS_TOKEN', nil)
      end

      it 'raises' do
        expect { described_class.new }.to raise_error(KeyError)
      end
    end

    context 'when CI_COMMIT_TAG is missing' do
      before do
        stub_env('CI_COMMIT_TAG', nil)
      end

      it 'raises' do
        expect { described_class.new }.to raise_error(KeyError)
      end
    end

    context 'when CI_COMMIT_TAG is a patch release' do
      before do
        stub_env('CI_COMMIT_TAG', 'v18.10.1-ee')
      end

      it 'exits 0' do
        expect { described_class.new }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(0)
        end
      end
    end

    context 'when CI_COMMIT_TAG is a release candidate' do
      before do
        stub_env('CI_COMMIT_TAG', 'v18.10.0-rc1')
      end

      it 'exits 0' do
        expect { described_class.new }.to raise_error(SystemExit) do |e|
          expect(e.status).to eq(0)
        end
      end
    end

    context 'when CI_COMMIT_TAG is a valid minor release' do
      it 'initializes without error' do
        expect { described_class.new }.not_to raise_error
      end
    end
  end

  describe '#execute' do
    subject(:script) { described_class.new }

    # commit_tag has minor > 0, so previous tag is computed directly (no tags API call)
    let(:from_tag) { 'self-hosted-v18.9.0-ee' }
    let(:to_tag) { 'self-hosted-v18.10.0-ee' }
    let(:from_sha) { 'aabbccdd11223344' }
    let(:from_tag_url) { "#{api_base}/projects/#{aigw_project_id}/repository/tags/#{from_tag}" }
    let(:commits_url) { "#{api_base}/projects/#{aigw_project_id}/repository/commits" }

    let(:from_tag_body) do
      { 'name' => from_tag, 'commit' => { 'id' => from_sha } }.to_json
    end

    # Two commits before from_sha: one flow-related, one not
    let(:commits_body) do
      [
        { 'id' => 'deadbeef0001', 'short_id' => 'deadbeef', 'title' => 'fix(code_review): improve output',
          'message' => '', 'web_url' => 'https://example.com/deadbeef' },
        { 'id' => 'cafebabe0002', 'short_id' => 'cafebabe', 'title' => 'chore: update deps',
          'message' => '', 'web_url' => 'https://example.com/cafebabe' },
        { 'id' => from_sha, 'short_id' => 'aabbccdd', 'title' => 'release: v18.9',
          'message' => '', 'web_url' => 'https://example.com/from' }
      ].to_json
    end

    before do
      stub_request(:get, from_tag_url)
        .to_return(status: 200, body: from_tag_body, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, commits_url)
        .with(query: hash_including('ref_name' => to_tag))
        .to_return(status: 200, body: commits_body, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, "#{api_base}/projects/#{aigw_project_id}/repository/commits/deadbeef0001/diff")
        .with(query: { 'per_page' => '100' })
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, "#{api_base}/projects/#{aigw_project_id}/repository/commits/cafebabe0002/diff")
        .with(query: { 'per_page' => '100' })
        .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when no previous self-hosted tag exists (first release of a major)' do
      before do
        stub_env('CI_COMMIT_TAG', 'v18.0.0-ee')
        stub_request(:get, "#{api_base}/projects/#{aigw_project_id}/repository/tags")
          .with(query: hash_including('search' => 'self-hosted-v17.'))
          .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'exits 0' do
        expect { script.execute }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end
    end

    context 'in dry-run mode' do
      before do
        allow(ARGV).to receive(:include?).with('--dry-run').and_return(true)
      end

      it 'prints the title and body without creating an issue' do
        expect { script.execute }.to output(/DRY RUN.*Title: DAP foundational flow major updates/m).to_stdout
        expect(a_request(:post, /issues/)).not_to have_been_made
      end
    end

    context 'when creating the issue succeeds' do
      let(:issue_url) { 'https://gitlab.com/my-group/my-project/-/issues/42' }

      before do
        stub_request(:post, "#{api_base}/projects/#{dap_project_id}/issues")
          .to_return(status: 201, body: { 'web_url' => issue_url }.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      it 'prints the created issue URL' do
        expect { script.execute }.to output(/#{Regexp.escape(issue_url)}/).to_stdout
      end

      it 'sends the correct title and labels' do
        script.execute

        expect(
          a_request(:post, "#{api_base}/projects/#{dap_project_id}/issues").with do |req|
            body = Gitlab::Json.safe_parse(req.body)
            body['title'] == 'DAP foundational flow major updates – v18.10' &&
              body['labels'].include?('group::agent foundations')
          end
        ).to have_been_made
      end
    end

    context 'when the issues API returns an error' do
      before do
        stub_request(:post, "#{api_base}/projects/#{dap_project_id}/issues")
          .to_return(status: 422, body: '{"message":"Validation failed"}')
      end

      it 'raises with the status code and response body' do
        expect { script.execute }.to raise_error(RuntimeError, /422.*Validation failed/m)
      end
    end
  end

  describe '#fetch_commits_between' do
    subject(:script) { described_class.new }

    let(:from_tag) { 'self-hosted-v18.9.0-ee' }
    let(:to_tag) { 'self-hosted-v18.10.0-ee' }
    let(:from_sha) { 'fromsha0000000001' }
    let(:from_tag_url) { "#{api_base}/projects/#{aigw_project_id}/repository/tags/#{from_tag}" }
    let(:commits_url) { "#{api_base}/projects/#{aigw_project_id}/repository/commits" }

    before do
      stub_request(:get, from_tag_url)
        .to_return(status: 200, body: { 'commit' => { 'id' => from_sha } }.to_json,
          headers: { 'Content-Type' => 'application/json' })
    end

    context 'when all commits fit on one page' do
      let(:commits) do
        [
          { 'id' => 'sha001', 'title' => 'feat: one' },
          { 'id' => 'sha002', 'title' => 'fix: two' },
          { 'id' => from_sha, 'title' => 'old: boundary' }
        ].to_json
      end

      before do
        stub_request(:get, commits_url)
          .with(query: hash_including('ref_name' => to_tag))
          .to_return(status: 200, body: commits, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns commits up to but not including from_sha' do
        result = script.send(:fetch_commits_between, from_tag, to_tag)
        expect(result.pluck('id')).to eq(%w[sha001 sha002])
      end
    end

    context 'when commits span multiple pages' do
      let(:page1) do
        Array.new(100) { |i| { 'id' => "sha#{i.to_s.rjust(3, '0')}", 'title' => "commit #{i}" } }.to_json
      end

      let(:page2) do
        [
          { 'id' => 'last001', 'title' => 'last commit' },
          { 'id' => from_sha, 'title' => 'boundary' }
        ].to_json
      end

      before do
        stub_request(:get, commits_url)
          .with(query: hash_including('page' => '1'))
          .to_return(status: 200, body: page1, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, commits_url)
          .with(query: hash_including('page' => '2'))
          .to_return(status: 200, body: page2, headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches all pages and stops at from_sha' do
        result = script.send(:fetch_commits_between, from_tag, to_tag)
        expect(result.length).to eq(101) # 100 from page 1 + 1 from page 2
        expect(result.last['id']).to eq('last001')
        expect(result.pluck('id')).not_to include(from_sha)
      end
    end

    context 'when the commits API returns an empty first page' do
      before do
        stub_request(:get, commits_url)
          .with(query: hash_including('ref_name' => to_tag))
          .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an empty array' do
        result = script.send(:fetch_commits_between, from_tag, to_tag)
        expect(result).to be_empty
      end
    end

    context 'when the last page has fewer than 100 commits and from_sha is not found' do
      let(:commits) do
        [
          { 'id' => 'sha001', 'title' => 'feat: one' },
          { 'id' => 'sha002', 'title' => 'fix: two' }
        ].to_json
      end

      before do
        stub_request(:get, commits_url)
          .with(query: hash_including('ref_name' => to_tag))
          .to_return(status: 200, body: commits, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns all commits on that page' do
        result = script.send(:fetch_commits_between, from_tag, to_tag)
        expect(result.pluck('id')).to eq(%w[sha001 sha002])
      end
    end

    context 'when the from tag cannot be resolved' do
      before do
        stub_request(:get, from_tag_url)
          .to_return(status: 200, body: { 'commit' => nil }.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an error' do
        expect { script.send(:fetch_commits_between, from_tag, to_tag) }
          .to raise_error(RuntimeError, /Could not resolve commit SHA/)
      end
    end
  end

  describe '#previous_self_hosted_tag' do
    subject(:script) { described_class.new }

    let(:tags_url) { "#{api_base}/projects/#{aigw_project_id}/repository/tags" }

    context 'when minor > 0' do
      it 'returns the computed previous tag without an API call' do
        expect(script.send(:previous_self_hosted_tag)).to eq('self-hosted-v18.9.0-ee')
        expect(a_request(:get, tags_url)).not_to have_been_made
      end
    end

    context 'when minor == 0' do
      before do
        stub_env('CI_COMMIT_TAG', 'v18.0.0-ee')
      end

      context 'and a previous major tag exists' do
        before do
          stub_request(:get, tags_url)
            .with(query: hash_including('search' => 'self-hosted-v17.', 'order_by' => 'version',
              'sort' => 'desc', 'per_page' => '1'))
            .to_return(status: 200, body: [{ 'name' => 'self-hosted-v17.11.0-ee' }].to_json,
              headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns the latest tag from the previous major' do
          expect(script.send(:previous_self_hosted_tag)).to eq('self-hosted-v17.11.0-ee')
        end
      end

      context 'and no tags exist for the previous major' do
        before do
          stub_request(:get, tags_url)
            .with(query: hash_including('search' => 'self-hosted-v17.'))
            .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns nil' do
          expect(script.send(:previous_self_hosted_tag)).to be_nil
        end
      end
    end
  end

  describe '#flow_related?' do
    subject(:script) { described_class.new }

    before do
      allow(script).to receive(:flow_references).and_return(%w[code_review fix_pipeline developer convert_to_gl_ci])
      stub_request(:get, diff_url)
              .with(query: { 'per_page' => '100' })
              .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })
    end

    let(:sha) { 'testsha001' }
    let(:diff_url) { "#{api_base}/projects/#{aigw_project_id}/repository/commits/#{sha}/diff" }

    def commit(title, message = '')
      { 'id' => sha, 'title' => title, 'message' => message }
    end

    it 'returns false for merge branch commits' do
      expect(script.send(:flow_related?, commit('Merge branch feature into master'))).to be(false)
    end

    it 'returns false for merge remote-tracking branch commits' do
      expect(script.send(:flow_related?, commit('Merge remote-tracking branch origin/main'))).to be(false)
    end

    it 'returns true when title contains a flow reference in conventional commit scope' do
      expect(script.send(:flow_related?, commit('fix(code_review): improve suggestions'))).to be(true)
    end

    it 'returns true when title mentions foundational flow' do
      expect(script.send(:flow_related?, commit('refactor: extract foundational flow helpers'))).to be(true)
    end

    it 'returns true when title matches the developer flow pattern' do
      expect(script.send(:flow_related?, commit('feat: update duo developer experience'))).to be(true)
    end

    it 'returns false for unrelated commits with no flow-related files' do
      expect(script.send(:flow_related?, commit('chore: update CI dependencies'))).to be(false)
    end

    context 'when the commit changes a file with a flow reference in its path' do
      before do
        diffs = [{ 'new_path' => 'duo_workflow_service/workflows/fix_pipeline/workflow.py',
                   'old_path' => 'duo_workflow_service/workflows/fix_pipeline/workflow.py' }]

        stub_request(:get, diff_url)
          .with(query: { 'per_page' => '100' })
          .to_return(status: 200, body: diffs.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns true even if the commit title is generic' do
        expect(script.send(:flow_related?, commit('chore: minor cleanup'))).to be(true)
      end
    end
  end

  describe '#flow_files_changed?' do
    subject(:script) { described_class.new }

    before do
      allow(script).to receive(:flow_references).and_return(%w[code_review fix_pipeline developer convert_to_gl_ci])
    end

    let(:sha) { 'diffsha001' }
    let(:diff_url) { "#{api_base}/projects/#{aigw_project_id}/repository/commits/#{sha}/diff" }

    def stub_diffs(diffs)
      stub_request(:get, diff_url)
        .with(query: { 'per_page' => '100' })
        .to_return(status: 200, body: diffs.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns true when a changed file path contains a flow reference as a path segment' do
      stub_diffs([{ 'new_path' => 'duo_workflow_service/workflows/fix_pipeline/workflow.py' }])
      expect(script.send(:flow_files_changed?, sha)).to be(true)
    end

    it 'returns true when the flow reference matches a filename stem' do
      stub_diffs([{ 'new_path' => 'duo_workflow_service/tools/code_review.py' }])
      expect(script.send(:flow_files_changed?, sha)).to be(true)
    end

    it 'returns false when no changed files contain a flow reference' do
      stub_diffs([{ 'new_path' => 'duo_workflow_service/utils/http_client.py' }])
      expect(script.send(:flow_files_changed?, sha)).to be(false)
    end

    it 'returns false when the diff is empty' do
      stub_diffs([])
      expect(script.send(:flow_files_changed?, sha)).to be(false)
    end

    it 'falls back to old_path when new_path is absent' do
      stub_diffs([{ 'old_path' => 'duo_workflow_service/tools/fix_pipeline.py', 'new_path' => nil }])
      expect(script.send(:flow_files_changed?, sha)).to be(true)
    end
  end

  describe '#flow_references' do
    subject(:script) { described_class.new }

    let(:flow_file_content) do
      <<~RUBY
        foundational_flow_reference: 'code_review'
        foundational_flow_reference: 'fix_pipeline/v1'
        foundational_flow_reference: 'developer'
        foundational_flow_reference: 'convert_to_gl_ci'
        foundational_flow_reference: 'code_review'
      RUBY
    end

    before do
      allow(script).to receive(:foundational_flow_content).and_return(flow_file_content)
    end

    it 'returns the base names of all foundational flows defined in the codebase' do
      refs = script.send(:flow_references)
      expect(refs).to include('code_review', 'fix_pipeline', 'developer', 'convert_to_gl_ci')
    end

    it 'strips version suffixes, returning only the base name' do
      refs = script.send(:flow_references)
      expect(refs).not_to include(match(%r{/}))
    end

    it 'returns unique values' do
      refs = script.send(:flow_references)
      expect(refs).to eq(refs.uniq)
    end

    context 'when EE file is absent' do
      before do
        allow(script).to receive(:foundational_flow_content).and_return(nil)
      end

      it 'returns an empty array' do
        expect(script.send(:flow_references)).to eq([])
      end
    end
  end

  describe '#foundational_flow_content' do
    subject(:script) { described_class.new }

    context 'when the EE foundational flow file exists' do
      it 'returns the file content as a string' do
        result = script.send(:foundational_flow_content)
        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end
    end

    context 'when the EE foundational flow file does not exist' do
      before do
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read)
          .with(a_string_ending_with('ee/app/models/ai/catalog/foundational_flow.rb'))
          .and_raise(Errno::ENOENT)
      end

      it 'returns nil' do
        expect(script.send(:foundational_flow_content)).to be_nil
      end
    end
  end

  describe '#build_issue_body' do
    subject(:script) { described_class.new }

    let(:from_tag) { 'self-hosted-v18.9.0-ee' }
    let(:to_tag) { 'self-hosted-v18.10.0-ee' }

    context 'with candidate commits' do
      let(:commits) do
        [
          { 'short_id' => 'abc123', 'title' => 'fix(code_review): better output',
            'web_url' => 'https://example.com/abc' },
          { 'short_id' => 'def456', 'title' => 'feat: markdown **bold** and _italic_',
            'web_url' => 'https://example.com/def' }
        ]
      end

      subject(:body) { script.send(:build_issue_body, from_tag, to_tag, commits, 7) }

      it 'includes the AI Gateway diff range link' do
        expect(body).to include("#{from_tag}...#{to_tag}")
      end

      it 'includes each commit SHA and URL' do
        expect(body).to include('[abc123](https://example.com/abc)')
        expect(body).to include('[def456](https://example.com/def)')
      end

      it 'escapes markdown special characters in commit titles' do
        expect(body).to include('fix(code\_review): better output')
        expect(body).to include('feat: markdown \*\*bold\*\* and \_italic\_')
      end

      it 'includes the count of other commits' do
        expect(body).to include('7 other commits')
      end
    end

    context 'with no candidate commits' do
      subject(:body) { script.send(:build_issue_body, from_tag, to_tag, [], 15) }

      it 'states no changes were detected' do
        expect(body).to include('No foundational flow changes detected automatically')
      end

      it 'still includes the diff link for manual review' do
        expect(body).to include("#{from_tag}...#{to_tag}")
      end
    end
  end

  describe '#escape_md' do
    subject(:script) { described_class.new }

    it 'escapes backslashes' do
      expect(script.send(:escape_md, 'a\\b')).to eq('a\\\\b')
    end

    it 'escapes asterisks' do
      expect(script.send(:escape_md, '**bold**')).to eq('\*\*bold\*\*')
    end

    it 'escapes underscores' do
      expect(script.send(:escape_md, '_italic_')).to eq('\_italic\_')
    end

    it 'escapes brackets' do
      expect(script.send(:escape_md, '[link](url)')).to eq('\[link\](url)')
    end

    it 'escapes backticks' do
      expect(script.send(:escape_md, '`code`')).to eq('\`code\`')
    end

    it 'leaves plain text unchanged' do
      expect(script.send(:escape_md, 'fix: update deps')).to eq('fix: update deps')
    end
  end
end
