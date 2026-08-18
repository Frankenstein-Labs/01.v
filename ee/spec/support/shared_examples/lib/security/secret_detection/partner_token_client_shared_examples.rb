# frozen_string_literal: true

# The fail-safe behaviour that EVERY partner token verifier must satisfy, whether
# it was hand-written or produced by the AI-assisted client generator. This is the
# safety net that lets us scale validity checks to many vendors without live
# tokens: even if we can never confirm the happy path for a vendor, we can always
# prove the client fails safe.
#
# Usage:
#   it_behaves_like 'a partner token client', http_method: :get,
#     malformed_tokens: ['nope', '', nil]
#
#   The including spec must also define `let(:valid_token) { ... }` - a
#   syntactically well-formed token for the vendor - since it's used by the
#   "unmapped/unexpected HTTP status" and "when a response is returned"
#   contexts to stub the HTTP call and drive `#verify_token`.
#   Omitting it raises a NameError.
RSpec.shared_examples 'a partner token client' do |http_method:, malformed_tokens:|
  # Both keywords are required, so omitting them fails at load time. An empty
  # list would not, and would silently drop the negative cases, so reject it.
  raise ArgumentError, 'malformed_tokens must list at least one token' if malformed_tokens.blank?

  let(:contract_client) { described_class.new }
  let(:contract_response) { instance_double(Net::HTTPResponse) }

  describe 'partner token client contract' do
    context 'with a malformed token' do
      before do
        allow(Integrations::Clients::HTTP).to receive(http_method)
        allow(Integrations::Clients::HTTP).to receive(:post)
        allow(Integrations::Clients::HTTP).to receive(:get)
      end

      malformed_tokens.each do |bad_token|
        it "returns unknown and makes no request for #{bad_token.inspect}" do
          result = contract_client.verify_token(bad_token)

          expect(result.unknown?).to be(true)
          expect(result.inactive?).to be(false)
          expect(Integrations::Clients::HTTP).not_to have_received(:get)
          expect(Integrations::Clients::HTTP).not_to have_received(:post)
        end
      end
    end

    context 'with an unmapped/unexpected HTTP status' do
      before do
        allow(contract_response).to receive_messages(code: '418', body: '')
        allow(Integrations::Clients::HTTP).to receive(http_method).and_return(contract_response)
      end

      it 'never reports the token as inactive' do
        result = contract_client.verify_token(valid_token)

        expect(result.inactive?).to be(false)
        expect(result.unknown?).to be(true)
      end
    end

    context 'when a response is returned' do
      before do
        allow(contract_response).to receive_messages(code: '200', body: '{"ok":true}')
        allow(Integrations::Clients::HTTP).to receive(http_method).and_return(contract_response)
      end

      it 'includes partner and verified_at' do
        result = contract_client.verify_token(valid_token)

        expect(result.metadata[:partner]).to be_present
        expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end
  end
end
