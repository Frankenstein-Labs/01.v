# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitalyClient, feature_category: :gitaly do
  context 'with composite identities', :request_store do
    let(:primary_user) { create(:user, :service_account, composite_identity_enforced: true) }
    let(:scoped_user) { create(:user) }
    let(:identity) { ::Gitlab::Auth::Identity.fabricate(primary_user) }
    let(:gitaly_context) do
      { 'scoped-user-id' => scoped_user.id.to_s }
    end

    before do
      identity.link!(scoped_user)
    end

    it 'encodes the scoped user ID' do
      metadata = described_class.request_kwargs('default', timeout: 1)[:metadata]

      expect(metadata['gitaly-client-context-bin']).to eq(gitaly_context.to_json)
    end

    it 'does not encode scoped user ID' do
      RequestStore.clear!

      metadata = described_class.request_kwargs('default', timeout: 1)[:metadata]

      expect(metadata.keys).not_to include('gitaly-client-context-bin')
    end
  end
end
