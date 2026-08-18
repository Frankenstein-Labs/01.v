# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::CheckService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
    let(:params) { { path: } }
    let(:upstreams) { registry.upstreams }
    let(:service) do
      described_class.new(upstreams:, params:)
    end

    subject(:execute) { service.execute }

    # CheckService now validates every upstream URL via PinnedRequestBuilder at
    # request time. Default to the real UrlBlocker so SSRF prevention tests for
    # localhost/loopback/link-local still work without explicit stubs; contexts
    # that need deterministic blocking override with `.with(url, anything)`.
    before do
      allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!).and_call_original
    end

    context 'for maven virtual registries' do
      include_context 'for check upstream service for maven packages'

      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
      let_it_be_with_reload(:upstream1) do
        create(:virtual_registries_packages_maven_upstream, registries: [registry])
      end

      let_it_be_with_reload(:upstream2) do
        create(:virtual_registries_packages_maven_upstream, registries: [registry])
      end

      let_it_be_with_reload(:upstream3) do
        create(:virtual_registries_packages_maven_upstream, registries: [registry])
      end

      # statuses is an array giving the status for each upstream
      where(:statuses, :expected_upstream) do
        [200, 200, 200] | ref(:upstream1)
        [404, 200, 200] | ref(:upstream2)
        [404, 404, 200] | ref(:upstream3)
      end

      with_them do
        before do
          stub_upstream_request(upstream1, status: statuses[0])
          stub_upstream_request(upstream2, status: statuses[1])
          stub_upstream_request(upstream3, status: statuses[2])
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when file not found in any upstream' do
        before do
          stub_upstream_request(upstream1, status: 404)
          stub_upstream_request(upstream2, status: 404)
          stub_upstream_request(upstream3, status: 404)
        end

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
      end

      context 'when an upstream fails' do
        before do
          stub_upstream_request(upstream1, status: 404)
          stub_upstream_request(upstream2, raise_error: true)
          stub_upstream_request(upstream3, status: 200)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::HTTP::BlockedUrlError)
        end
      end

      context 'when an upstream after the one with the file fails' do
        let(:expected_upstream) { upstream2 }

        before do
          stub_upstream_request(upstream1, status: 404)
          stub_upstream_request(upstream2, status: 200)
          stub_upstream_request(upstream3, raise_error: true)
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when upstream returns a redirect' do
        let(:redirect_target) { 'https://redirected.example.com/package.pom' }

        context 'when redirect target is valid external URL' do
          let(:expected_upstream) { upstream1 }

          before do
            stub_upstream_redirect(upstream1, redirect_to: redirect_target, final_status: 200)
            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it_behaves_like 'returning a service success response with upstream'
        end

        context 'when redirect target returns 404' do
          before do
            stub_upstream_redirect(upstream1, redirect_to: redirect_target, final_status: 404)
            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when following multiple redirects within limit' do
          let(:expected_upstream) { upstream1 }
          let(:redirect_chain) do
            [
              'https://redirect1.example.com/path',
              'https://redirect2.example.com/path',
              'https://redirect3.example.com/path'
            ]
          end

          before do
            stub_upstream_chained_redirects(upstream1, redirect_chain: redirect_chain, final_status: 200)
            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it_behaves_like 'returning a service success response with upstream'
        end

        context 'when redirect count exceeds maximum' do
          let(:max_redirects) { VirtualRegistries::Upstreams::Remote::RedirectHandler::MAX_REDIRECTS }
          let(:redirect_chain) do
            (1..max_redirects + 1).map { |i| "https://redirect#{i}.example.com/path" }
          end

          before do
            stub_upstream_chained_redirects(upstream1, redirect_chain: redirect_chain, final_status: 200)
            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when first upstream redirects but second succeeds directly' do
          let(:expected_upstream) { upstream1 }

          before do
            stub_upstream_redirect(upstream1, redirect_to: redirect_target, final_status: 200)
            stub_upstream_request(upstream2, status: 200)
            stub_upstream_request(upstream3, status: 404)
          end

          it 'returns the first upstream (priority preserved)' do
            result = execute

            expect(result).to be_success
            expect(result.payload[:upstream]).to eq(upstream1)
          end
        end

        context 'when the redirect stays on the same host' do
          let(:expected_upstream) { upstream1 }
          let(:redirect_target) do
            base = Addressable::URI.parse(upstream1.url_for(path))
            "#{base.scheme}://#{base.host}/redirected/package.pom"
          end

          before do
            stub_upstream_same_host_redirect(upstream1, redirect_to: redirect_target, final_status: 200)
            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it_behaves_like 'returning a service success response with upstream'

          it 'forwards the credentials to the same-host redirect target' do
            execute

            expect(a_request(:head, redirect_target).with(headers: upstream1.headers)).to have_been_made
          end
        end
      end

      context 'with SSRF prevention' do
        context 'when redirect target is localhost' do
          before do
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'http://localhost:3000/internal' })

            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when redirect target is loopback address' do
          before do
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'http://127.0.0.1:3333/internal' })

            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when redirect target is private network address' do
          using RSpec::Parameterized::TableSyntax

          where(:blocked_url) do
            [
              'http://10.0.0.1/internal',
              'http://172.16.0.1/internal',
              'http://192.168.1.1/internal'
            ]
          end

          with_them do
            before do
              stub_request(:head, upstream1.url_for(path))
                .with(headers: upstream1.headers)
                .to_return(status: 302, headers: { 'Location' => blocked_url })

              stub_upstream_request(upstream2, status: 404)
              stub_upstream_request(upstream3, status: 404)
            end

            it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
          end
        end

        context 'when redirect target is AWS metadata endpoint' do
          before do
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'http://169.254.169.254/latest/meta-data/' })

            allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
              .with('http://169.254.169.254/latest/meta-data/', anything)
              .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'Requests to link local network are not allowed')

            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when chained redirect ends at internal address' do
          before do
            # First redirect to external
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'https://external.example.com/redirect' })

            # Second redirect to internal (cross-host hop: credentials stripped)
            stub_cross_host_redirect_follow('https://external.example.com/redirect', upstream: upstream1,
              status: 302, headers: { 'Location' => 'http://127.0.0.1:8080/internal' })

            stub_upstream_request(upstream2, status: 404)
            stub_upstream_request(upstream3, status: 404)
          end

          it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
        end

        context 'when redirect is blocked but another upstream succeeds' do
          let(:expected_upstream) { upstream2 }

          before do
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'http://127.0.0.1:3000/internal' })

            stub_upstream_request(upstream2, status: 200)
            stub_upstream_request(upstream3, status: 404)
          end

          it_behaves_like 'returning a service success response with upstream'
        end

        context 'when redirect is blocked after another upstream already succeeded' do
          let(:expected_upstream) { upstream3 }

          before do
            # upstream1: First redirect is valid, second redirect is blocked
            # This ensures the blocked redirect is processed AFTER upstream3 succeeds
            stub_request(:head, upstream1.url_for(path))
              .with(headers: upstream1.headers)
              .to_return(status: 302, headers: { 'Location' => 'https://external.example.com/valid' })

            # Cross-host hop: credentials stripped before following
            stub_cross_host_redirect_follow('https://external.example.com/valid', upstream: upstream1,
              status: 302, headers: { 'Location' => 'http://127.0.0.1:3000/blocked' })

            # upstream2: Returns 404 (no abort triggered)
            stub_upstream_request(upstream2, status: 404)

            # upstream3: Returns 200 (triggers abort, but follow request already queued)
            stub_upstream_request(upstream3, status: 200)
          end

          it_behaves_like 'returning a service success response with upstream'
        end
      end

      context 'when initial upstream URL is blocked at request time' do
        # Mirrors the DNS rebinding TOCTOU for redirect targets, but on the
        # initial request: the upstream URL passes the model's save-time
        # validation, but by request time DNS has flipped to an internal IP and
        # UrlBlocker rejects it. PinnedRequestBuilder must return nil so no
        # HEAD request is dispatched to the rebinding target; the upstream is
        # marked failed and lower-priority upstreams still get their chance.
        let(:expected_upstream) { upstream2 }

        before do
          allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
            .with(upstream1.url_for(path), anything)
            .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'Requests to the local network are not allowed')

          stub_upstream_request(upstream2, status: 200)
          stub_upstream_request(upstream3, status: 404)
        end

        it_behaves_like 'returning a service success response with upstream'

        it 'does not dispatch a request to the blocked upstream' do
          execute

          expect(WebMock).not_to have_requested(:head, upstream1.url_for(path))
        end
      end
    end

    context 'for container virtual registries' do
      include_context 'for check upstream service for container images'

      let_it_be(:registry) { create(:virtual_registries_container_registry) }

      let_it_be_with_reload(:upstream1) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be_with_reload(:upstream2) { create(:virtual_registries_container_upstream, registries: [registry]) }
      let_it_be_with_reload(:upstream3) { create(:virtual_registries_container_upstream, registries: [registry]) }

      let(:path) { 'library/alpine/manifests/3.19' }
      let(:scope) { 'repository:library/alpine:pull' }

      # statuses is an array giving the status for each upstream
      where(:statuses, :expected_upstream) do
        [200, 200, 200] | ref(:upstream1)
        [404, 200, 200] | ref(:upstream2)
        [404, 404, 200] | ref(:upstream3)
      end

      with_them do
        before do
          stub_upstream_request(upstream1, status: statuses[0], scope: scope)
          stub_upstream_request(upstream2, status: statuses[1], scope: scope)
          stub_upstream_request(upstream3, status: statuses[2], scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end

      context 'when file not found in any upstream' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 404, scope: scope)
          stub_upstream_request(upstream3, status: 404, scope: scope)
        end

        it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
      end

      context 'when an upstream fails' do
        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, raise_error: true, scope: scope)
          stub_upstream_request(upstream3, status: 200, scope: scope)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::HTTP::BlockedUrlError)
        end
      end

      context 'when an upstream after the one with the file fails' do
        let(:expected_upstream) { upstream2 }

        before do
          stub_upstream_request(upstream1, status: 404, scope: scope)
          stub_upstream_request(upstream2, status: 200, scope: scope)
          stub_upstream_request(upstream3, raise_error: true, scope: scope)
        end

        it_behaves_like 'returning a service success response with upstream'
      end
    end

    it_behaves_like 'a check upstream service handling no path set'
    it_behaves_like 'a check upstream service handling empty upstreams'
  end
end
