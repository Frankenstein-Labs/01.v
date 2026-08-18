# frozen_string_literal: true

RSpec.shared_context 'with kubernetes agent service' do
  before do
    allow(Gitlab::Kas).to receive(:enabled?).and_return(true)
    allow_next_instance_of(Gitlab::Kas::Client) do |client|
      # rubocop:disable RSpec/VerifiedDoubles -- Prevent NoMethodError that occurs when using instance double
      allow(client).to receive(:get_connected_agentks_by_agent_ids).and_return([double(agent_id: agent.id,
        connected_at: 30.minutes)])
      # rubocop:enable RSpec/VerifiedDoubles
    end
  end
end
