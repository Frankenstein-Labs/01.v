# frozen_string_literal: true

RSpec.shared_examples 'a service for listing secrets needing rotation' do |resource_type|
  # Note: The including spec must define:
  # - service (the service instance)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - create_rotation_secret (method accepting name: and rotation_interval_days:)
  # - user (the user performing the operation)

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context "when the #{resource_type} secrets manager is active and user is owner" do
      before do
        provision_secrets_manager(secrets_manager, user)
      end

      context 'when there are no secrets' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:secrets]).to eq([])
        end
      end

      context 'when there are secrets but none need rotation' do
        before do
          create_rotation_secret(name: 'OK_SECRET', rotation_interval_days: 365)
        end

        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:secrets]).to eq([])
        end
      end

      context 'when there are secrets needing rotation' do
        let!(:overdue_secret_old) do
          create_rotation_secret(name: 'OVERDUE_OLD', rotation_interval_days: 30)
        end

        let!(:approaching_secret_soon) do
          create_rotation_secret(name: 'APPROACHING_SOON', rotation_interval_days: 30)
        end

        let!(:overdue_secret_new) do
          create_rotation_secret(name: 'OVERDUE_NEW', rotation_interval_days: 30)
        end

        let!(:ok_secret) do
          create_rotation_secret(name: 'OK_SECRET', rotation_interval_days: 365)
        end

        let!(:non_rotating_secret) do
          create_rotation_secret(name: 'NON_ROTATING_SECRET', rotation_interval_days: nil)
        end

        let!(:approaching_secret_later) do
          create_rotation_secret(name: 'APPROACHING_LATER', rotation_interval_days: 30)
        end

        before do
          overdue_secret_old.rotation_info.update_columns(
            created_at: 3.months.ago,
            last_reminder_at: 1.day.ago
          )

          overdue_secret_new.rotation_info.update_columns(
            created_at: 1.week.ago,
            last_reminder_at: 1.day.ago
          )

          approaching_secret_soon.rotation_info.update_columns(
            next_reminder_at: 2.days.from_now
          )

          approaching_secret_later.rotation_info.update_columns(
            next_reminder_at: 6.days.from_now
          )
        end

        it 'returns only secrets needing rotation in correct priority order' do
          expect(result).to be_success

          secrets = result.payload[:secrets]

          expect(secrets.map(&:name)).to eq(%w[
            OVERDUE_OLD
            OVERDUE_NEW
            APPROACHING_SOON
            APPROACHING_LATER
          ])
        end
      end
    end

    context "when the #{resource_type} secrets manager is not active" do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
