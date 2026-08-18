# frozen_string_literal: true

RSpec.shared_examples 'write access for a read-only GitLab (EE) instance' do
  include Rack::Test::Methods
  using RSpec::Parameterized::TableSyntax

  include_context 'with a mocked GitLab instance'

  context 'normal requests to a read-only GitLab instance' do
    let(:fake_app) { ->(env) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }

    it_behaves_like 'allowlisted /admin/geo requests'

    context 'on Geo secondary' do
      before do
        allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
      end

      where(:description, :path) do
        'LFS request to batch'        | '/root/rouge.git/info/lfs/objects/batch'
        'LFS request to locks verify' | '/root/rouge.git/info/lfs/locks/verify'
        'LFS request to locks create' | '/root/rouge.git/info/lfs/locks'
        'LFS request to locks unlock' | '/root/rouge.git/info/lfs/locks/1/unlock'
        'to geo replication node api' | "/api/#{API::API.version}/geo_replication/designs/resync"
        'git-receive-pack'            | '/root/rouge.git/git-receive-pack'
      end

      with_them do
        it "expects a POST #{description} URL to be allowed" do
          response = request.post(path)

          expect(response).not_to be_redirect
          expect(subject).not_to disallow_request
        end

        it "expects a POST #{description} URL with a trailing slash to be allowed" do
          response = request.post("#{path}/")

          expect(response).not_to be_redirect
          expect(subject).not_to disallow_request
        end
      end

      context 'when a relative URL root is configured' do
        let(:relative_url_root) { '/gitlab' }

        before do
          stub_config_setting(relative_url_root:)
        end

        it 'allows Geo git SSH proxy requests' do
          response = request.post(File.join(relative_url_root, "api/#{API::API.version}/geo/proxy_git_ssh"))

          expect(response).not_to be_redirect
          expect(subject).not_to disallow_request
        end
      end

      context 'when the content type is a text/plain' do
        let(:response) { request.patch('/test_request') }

        it 'redirect with read only instance error message' do
          expect(Gitlab::AppLogger).to receive(:error)
            .with(described_class::Controller::READ_ONLY_INSTANCE_ERROR_MESSAGE)

          expect(response).to be_redirect
          expect(readonly_middleware).to disallow_request
        end
      end

      context 'when the content type is application/json' do
        let(:fake_app) { ->(_env) { [200, { 'Content-Type' => 'application/json' }, ['OK']] } }
        let(:response) { request.patch('/test_request', { 'CONTENT_TYPE' => 'application/json' }) }

        it 'returns forbidden with read only instance error message' do
          expect(Gitlab::AppLogger).to receive(:error)
            .with(described_class::Controller::READ_ONLY_INSTANCE_ERROR_MESSAGE)

          expect(response).to disallow_request_in_json
          expect(response).to be_forbidden
        end
      end
    end
  end
end
