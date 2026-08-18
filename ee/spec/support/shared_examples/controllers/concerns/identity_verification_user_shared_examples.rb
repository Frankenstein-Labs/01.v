# frozen_string_literal: true

RSpec.shared_context 'with a signed-in IdentityVerificationUser' do
  include SessionHelpers

  before do
    stub_session(session_data: { verification_user_id: verification_user_id })
  end
end

RSpec.shared_examples 'it handles absence of a signed-in IdentityVerificationUser' do
  include SessionHelpers

  before do
    stub_session(session_data: { verification_user_id: non_existing_record_id })
  end

  it 'handles sticking' do
    allow(User.sticking).to receive(:find_caught_up_replica)
    .and_call_original

    expect(User.sticking)
      .to receive(:find_caught_up_replica)
      .with(:user, non_existing_record_id, hash_id: false)

    do_request

    stick_object = request.env[::Gitlab::Database::LoadBalancing::RackMiddleware::STICK_OBJECT].first
    expect(stick_object[0]).to eq(User.sticking)
    expect(stick_object[1]).to eq(:user)
    expect(stick_object[2]).to eq(non_existing_record_id)
  end
end
