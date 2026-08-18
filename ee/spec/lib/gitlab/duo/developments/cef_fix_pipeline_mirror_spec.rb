# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::CefFixPipelineMirror, feature_category: :duo_chat do
  describe 'constants' do
    it 'defines the production source as gitlab.com' do
      expect(described_class::SOURCE_GITLAB_URL).to eq('https://gitlab.com')
    end

    it 'targets the curated LangSmith dataset' do
      expect(described_class::SOURCE_LANGSMITH_DATASET).to eq('cef.fix_pipeline.materialized.v1')
    end

    it 'defaults to the gitlab-duo destination namespace' do
      expect(described_class::DEFAULT_GROUP_PATH).to eq('gitlab-duo')
    end

    it 'declares retry attempts and backoff', :aggregate_failures do
      expect(described_class::HTTP_RETRY_ATTEMPTS).to be > 0
      expect(described_class::HTTP_RETRY_BASE_DELAY_S).to be > 0
    end
  end

  describe '.parse_pipeline_url' do
    subject(:parse) { described_class.send(:parse_pipeline_url, url) }

    context 'with a valid gitlab.com pipeline URL' do
      let(:url) do
        'https://gitlab.com/gitlab-org/duo-workflow/test-project-playground/' \
          'duofixfailingpipelinecef/-/pipelines/12345'
      end

      it 'returns the project path and integer pipeline id', :aggregate_failures do
        path, pid = parse
        expect(path).to eq('gitlab-org/duo-workflow/test-project-playground/duofixfailingpipelinecef')
        expect(pid).to eq(12345)
      end
    end

    context 'with a malformed URL' do
      let(:url) { 'not-a-pipeline-url' }

      it 'returns [nil, nil]' do
        expect(parse).to eq([nil, nil])
      end
    end

    context 'with http scheme' do
      let(:url) { 'http://gitlab.example/group/project/-/pipelines/42' }

      it 'still parses' do
        expect(parse).to eq(['group/project', 42])
      end
    end
  end

  describe '.eligible_row?' do
    subject(:eligible) { described_class.send(:eligible_row?, row, 'FP-001') }

    context 'when the row has source_branch and prod_pipeline_url' do
      let(:row) do
        { 'source_branch' => 'fp-001/foo', 'prod_pipeline_url' => 'https://gitlab.com/x/-/pipelines/1' }
      end

      it 'is eligible' do
        expect(eligible).to be true
      end
    end

    context "when authentic is explicitly 'skipped'" do
      let(:row) { { 'authentic' => 'skipped', 'source_branch' => 'fp-001/foo', 'prod_pipeline_url' => 'x' } }

      it 'is not eligible' do
        expect { expect(eligible).to be false }.to output(/skipped/).to_stdout
      end
    end

    context 'when source_branch is blank' do
      let(:row) { { 'prod_pipeline_url' => 'x' } }

      it 'is not eligible' do
        expect { expect(eligible).to be false }.to output(/skipped/).to_stdout
      end
    end
  end

  describe '.parse_jsonl_rows' do
    subject(:parsed) { described_class.send(:parse_jsonl_rows, body) }

    let(:body) do
      [
        { inputs: { id: 'A', source_branch: 'fp-001/x' }, outputs: { expected_action: 'no_action' },
          metadata: { fp_id: 'FP-001' } }.to_json,
        { inputs: { id: 'B', source_branch: 'fp-005/y' }, outputs: { expected_action: 'fix_on_existing_mr' },
          metadata: { fp_id: 'FP-005', authentic: 'yes' } }.to_json
      ].join("\n")
    end

    it 'merges inputs + outputs and copies fp_id from metadata', :aggregate_failures do
      expect(parsed.size).to eq(2)
      expect(parsed[0]).to include('source_branch' => 'fp-001/x', 'expected_action' => 'no_action',
        'fp_id' => 'FP-001')
      expect(parsed[1]).to include('source_branch' => 'fp-005/y', 'fp_id' => 'FP-005', 'authentic' => 'yes')
    end

    it 'skips lines that are not JSON objects' do
      result = described_class.send(:parse_jsonl_rows, "not json\n{}\n")
      expect(result).to eq([{}])
    end
  end

  describe '.find_or_create_local_stage' do
    let_it_be(:project) { create(:project) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

    it 'creates a stage when none exists with that name' do
      expect do
        described_class.send(:find_or_create_local_stage, pipeline, 'test', 0)
      end.to change { pipeline.stages.count }.by(1)
    end

    it 'returns the existing stage on the second call (idempotent)' do
      first = described_class.send(:find_or_create_local_stage, pipeline, 'test', 0)

      expect do
        second = described_class.send(:find_or_create_local_stage, pipeline, 'test', 0)
        expect(second.id).to eq(first.id)
      end.not_to change { pipeline.stages.count }
    end
  end

  describe '.find_local_pipeline' do
    let_it_be(:project) { create(:project, :small_repo) }
    let(:source_branch) { project.default_branch }

    let_it_be(:head_sha) { project.repository.commit.id }
    let_it_be(:older_sha) { 'deadbeef' * 5 }

    let_it_be(:older_pipeline) do
      create(:ci_pipeline, project: project, ref: project.default_branch, sha: older_sha, source: 'push')
    end

    let_it_be(:head_pipeline) do
      create(:ci_pipeline, project: project, ref: 'refs/merge-requests/1/head', sha: head_sha,
        source: 'merge_request_event')
    end

    it "prefers the pipeline whose sha matches the branch's HEAD even if its ref isn't the branch" do
      result = described_class.send(:find_local_pipeline, project, source_branch)
      expect(result).to eq(head_pipeline)
    end

    context 'when the HEAD sha carries both a branch-ref and a merge-request-ref pipeline' do
      # Deliberately created so the merge-request-ref pipeline has the HIGHER id, which is the usual
      # real-world ordering: pushing the branch creates the branch pipeline, then opening or updating
      # the MR creates the merge_request_event one. A plain `order(id: :desc)` therefore picks the
      # merge-request ref, which is the bug this guards.
      let_it_be(:branch_ref_pipeline) do
        create(:ci_pipeline, project: project, ref: project.default_branch, sha: head_sha, source: 'push')
      end

      let_it_be(:later_mr_ref_pipeline) do
        create(:ci_pipeline, project: project, ref: 'refs/merge-requests/2/head', sha: head_sha,
          source: 'merge_request_event')
      end

      # The eval passes the chosen pipeline's `ref` to the fix_pipeline flow, whose checkout step
      # builds `git checkout -B <ref> --track origin/<ref>`. That resolves only for a branch name,
      # so picking the merge-request ref here makes the checkout unsatisfiable and silently removes
      # the flow's whole fix-producing path from the eval.
      it 'prefers the branch-ref pipeline over a newer merge-request-ref pipeline', :aggregate_failures do
        result = described_class.send(:find_local_pipeline, project, source_branch)

        expect(result).to eq(branch_ref_pipeline)
        expect(later_mr_ref_pipeline.id).to be > branch_ref_pipeline.id
      end
    end

    context 'when a tag pipeline shares the branch name' do
      # `for_branch` is `for_ref(branch).where(tag: false)`, so the preference clause cannot mistake a
      # tag for the branch pipeline. The tag is created last, so a bare `for_ref` would pick it on
      # `order(id: :desc)`. Theoretical for a seeded GDK, but it is what distinguishes the scope's
      # name from what `for_ref` alone would mean.
      let_it_be(:real_branch_pipeline) do
        create(:ci_pipeline, project: project, ref: project.default_branch, sha: head_sha, source: 'push')
      end

      let_it_be(:later_tag_pipeline) do
        create(:ci_pipeline, project: project, ref: project.default_branch, sha: head_sha,
          source: 'push', tag: true)
      end

      it 'prefers the branch pipeline over a newer tag pipeline of the same name', :aggregate_failures do
        expect(described_class.send(:find_local_pipeline, project, source_branch)).to eq(real_branch_pipeline)
        expect(later_tag_pipeline.id).to be > real_branch_pipeline.id
      end
    end

    it 'returns nil for an unknown branch' do
      expect(described_class.send(:find_local_pipeline, project, 'no-such-branch')).to be_nil
    end
  end

  describe '.replay_one_row' do
    let_it_be(:project) { create(:project, :small_repo) }
    let(:source_branch) { project.default_branch }
    let(:row) do
      { 'source_branch' => source_branch,
        'prod_pipeline_url' => 'https://gitlab.com/g/p/-/pipelines/123' }
    end

    before do
      allow(described_class).to receive_messages(replay_pipeline_traces: true, replay_downstreams: false)
    end

    context 'when the resolved pipeline is on the branch' do
      let_it_be(:branch_pipeline) do
        create(:ci_pipeline, project: project, ref: project.default_branch, source: 'push')
      end

      before do
        allow(described_class).to receive(:find_local_pipeline).and_return(branch_pipeline)
      end

      it 'does not warn about the ref' do
        expect { described_class.send(:replay_one_row, row, 'FP-001', project, 'token') }
          .not_to output(/not branch/).to_stdout
      end
    end

    context 'when the resolved pipeline is on a merge-request ref' do
      let_it_be(:mr_ref_pipeline) do
        create(:ci_pipeline, project: project, ref: 'refs/merge-requests/1/head',
          source: 'merge_request_event')
      end

      before do
        allow(described_class).to receive(:find_local_pipeline).and_return(mr_ref_pipeline)
      end

      # The flow builds `git checkout -B <ref> --track origin/<ref>` from this ref, which cannot
      # resolve. Downstream the failure is silent -- the run reports success having changed nothing --
      # so the mirror has to be the thing that says it.
      it 'warns that the fixture is not on the branch' do
        warning = "WARN: pipeline #{mr_ref_pipeline.id} is on ref refs/merge-requests/1/head, " \
          "not branch #{source_branch}"

        expect { described_class.send(:replay_one_row, row, 'FP-001', project, 'token') }
          .to output(/#{Regexp.escape(warning)}/).to_stdout
      end
    end
  end

  describe '.write_url_override_yaml' do
    let(:rows) { [{ 'fp_id' => 'FP-001', 'prod_pipeline_url' => 'a', 'pipeline_url' => 'b' }] }

    it 'writes to an absolute path verbatim' do
      Dir.mktmpdir do |tmp|
        path = File.join(tmp, 'override.yml')
        returned = described_class.send(:write_url_override_yaml, rows, path)
        expect(returned).to eq(path)
        expect(File.exist?(path)).to be true
        expect(YAML.safe_load(File.read(path))).to eq(rows)
      end
    end

    it 'resolves bare filenames against the current working directory' do
      Dir.mktmpdir do |tmp|
        Dir.chdir(tmp) do
          returned = described_class.send(:write_url_override_yaml, rows, 'override.yml')
          expect(returned).to eq(File.expand_path('override.yml'))
          expect(File.exist?('override.yml')).to be true
        end
      end
    end
  end

  describe '.http_get_with_retry' do
    let(:url) { 'https://example.test/path' }

    before do
      allow(described_class).to receive(:sleep)
    end

    context 'on a successful response' do
      let(:response) { instance_double(HTTParty::Response, body: 'ok', success?: true, code: 200) }

      before do
        allow(::Gitlab::HTTP).to receive(:get).and_return(response)
      end

      it 'returns the body without retrying' do
        expect(::Gitlab::HTTP).to receive(:get).once
        expect(described_class.send(:http_get_with_retry, url, headers: {}, label: 'test')).to eq('ok')
      end
    end

    context 'on a 503 followed by 200' do
      let(:fail_response) { instance_double(HTTParty::Response, body: 'down', success?: false, code: 503) }
      let(:ok_response) { instance_double(HTTParty::Response, body: 'ok', success?: true, code: 200) }

      before do
        responses = [fail_response, ok_response]
        allow(::Gitlab::HTTP).to receive(:get) { responses.shift }
      end

      it 'retries and eventually returns the success body' do
        expect(described_class.send(:http_get_with_retry, url, headers: {}, label: 'test')).to eq('ok')
      end
    end

    context 'on a 404 (not retryable)' do
      let(:response) { instance_double(HTTParty::Response, body: 'missing', success?: false, code: 404) }

      before do
        allow(::Gitlab::HTTP).to receive(:get).and_return(response)
      end

      it 'raises immediately without retrying' do
        expect(::Gitlab::HTTP).to receive(:get).once
        expect do
          described_class.send(:http_get_with_retry, url, headers: {}, label: 'test')
        end.to raise_error(/404/)
      end
    end

    context 'on a connection error' do
      before do
        allow(::Gitlab::HTTP).to receive(:get).and_raise(Errno::ECONNREFUSED)
      end

      it 'retries up to HTTP_RETRY_ATTEMPTS then raises' do
        expect(::Gitlab::HTTP).to receive(:get).exactly(described_class::HTTP_RETRY_ATTEMPTS).times
        expect do
          described_class.send(:http_get_with_retry, url, headers: {}, label: 'test')
        end.to raise_error(Errno::ECONNREFUSED)
      end
    end
  end

  describe '.mirror' do
    let_it_be(:admin_user) { create(:user, :admin) }
    let_it_be(:group) { create(:group, path: 'gitlab-duo') }
    let_it_be(:project) { create(:project, :small_repo, namespace: group, path: 'duofixfailingpipelinecef') }

    before do
      stub_env('GITLAB_COM_AT', 'gl-token')
      stub_env('LANGCHAIN_API_KEY', 'ls-key')

      # Defang network: any outbound HTTP becomes a controlled stub. Stub
      # find_root_user so the spec doesn't depend on a 'root' username
      # existing in the test DB (which can collide with other specs).
      allow(described_class).to receive_messages(
        find_root_user: admin_user,
        probe_gitlab_com: nil,
        probe_langsmith: nil,
        fetch_prod_manifest_from_langsmith: [],
        repair_against_prod: nil,
        replay_traces: [],
        verify_completeness: true
      )
    end

    around do |ex|
      Dir.mktmpdir { |tmp| Dir.chdir(tmp) { ex.run } }
    end

    it 'returns true when verification passes' do
      expect(described_class.mirror(group_path: 'gitlab-duo', project_path: 'duofixfailingpipelinecef')).to be true
    end

    it 'aborts when GITLAB_COM_AT is unset' do
      stub_env('GITLAB_COM_AT', nil)
      expect { described_class.mirror }.to raise_error(SystemExit)
    end

    it 'aborts when LANGCHAIN_API_KEY is unset' do
      stub_env('LANGCHAIN_API_KEY', nil)
      expect { described_class.mirror }.to raise_error(SystemExit)
    end

    it 'aborts when the destination namespace does not exist' do
      expect { described_class.mirror(group_path: 'no-such-group') }.to raise_error(SystemExit)
    end

    it 'aborts when the destination project has not been imported locally' do
      expect do
        described_class.mirror(group_path: 'gitlab-duo', project_path: 'not-imported-yet')
      end.to raise_error(SystemExit)
    end

    context 'when verify_completeness reports gaps' do
      before do
        allow(described_class).to receive(:verify_completeness).and_return(false)
      end

      it 'returns false (so the rake task can abort)' do
        expect(described_class.mirror(group_path: 'gitlab-duo',
          project_path: 'duofixfailingpipelinecef')).to be false
      end
    end
  end
end
