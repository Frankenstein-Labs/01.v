# frozen_string_literal: true

RSpec.shared_examples 'perform with session state' do
  describe '.perform_async' do
    let(:merge_request_id) { 456 }
    let(:user_id) { 123 }
    let(:ip_address) { '1.1.1.1' }
    let(:session_id) { 'abc' }

    before do
      allow(::Gitlab::IpAddressState).to receive(:current).and_return(ip_address)
      allow(::Gitlab::Session).to receive(:session_id_for_worker).and_return(session_id)
    end

    it 'sets ip_address_state and set_session_id' do
      worker.perform_async(merge_request_id, user_id)

      job = worker.jobs.first

      expect(job).to include(
        'ip_address_state' => ip_address,
        'set_session_id' => session_id,
        'args' => [merge_request_id, user_id]
      )
    end
  end
end
