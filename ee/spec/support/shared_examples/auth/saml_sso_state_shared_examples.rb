# frozen_string_literal: true

RSpec.shared_examples_for 'SAML SSO State checks for session_not_on_or_after' do |saml_type|
  describe '#active_since?' do
    let(:cutoff) { 1.week.ago }

    context 'when session_not_on_or_after is supplied' do
      context 'when session has expired' do
        let(:expired_time) { 1.hour.ago.iso8601 }

        it 'returns false even if cutoff is met' do
          time_after_cut_off = cutoff + 2.days

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => time_after_cut_off,
              "#{saml_provider_id}_session_not_on_or_after" => expired_time
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => time_after_cut_off,
                                    'session_not_on_or_after' => expired_time }
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end
        end

        it 'returns false when cutoff is not met' do
          time_before_cut_off = cutoff - 2.days

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => time_before_cut_off,
              "#{saml_provider_id}_session_not_on_or_after" => expired_time
            }) do
              is_expected.not_to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => time_before_cut_off,
                                    'session_not_on_or_after' => expired_time }
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end
        end
      end

      context 'when session has not expired' do
        let(:future_time) { 1.hour.from_now.iso8601 }
        let(:last_signin_time_in_future) { 3.hours.from_now }

        it 'returns true' do
          cutoff = 2.hours.ago

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => last_signin_time_in_future,
              "#{saml_provider_id}_session_not_on_or_after" => future_time
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => last_signin_time_in_future,
                                    'session_not_on_or_after' => future_time }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end

        it 'returns true and cutoff value is not considered' do
          cutoff = 4.hours.from_now

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => last_signin_time_in_future,
              "#{saml_provider_id}_session_not_on_or_after" => future_time
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => last_signin_time_in_future,
                                    'session_not_on_or_after' => future_time }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end
      end

      context 'when session_not_on_or_after is not set' do
        it 'considers cutoff value to decide sso_state active' do
          cutoff = 2.hours.ago

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => Time.current
            }) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => Time.current }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end
      end
    end
  end
end
