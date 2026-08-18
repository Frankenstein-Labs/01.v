# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignments::SelfManaged::CreateService, feature_category: :seat_cost_management do
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on) }
  let_it_be(:user) { create(:user) }

  subject(:response) do
    described_class.new(add_on_purchase: add_on_purchase, user: user).execute
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: false)
    ::Users::Internal.in_organization(user.organization_id).duo_code_review_bot # ensure interal user exists
  end

  describe '#execute' do
    let(:log_params) do
      {
        username: user.username,
        add_on: add_on_purchase.add_on.name
      }
    end

    shared_examples 'success response' do
      it 'creates new records' do
        expect(Gitlab::AppLogger).to receive(:info).with(log_params.merge(message: 'User AddOn assignment created'))

        expect { subject }.to change { add_on_purchase.assigned_users.where(user: user).count }.by(1)
        expect(response).to be_success
      end

      it 'expires the user add-on cache', :use_clean_rails_redis_caching do
        cache_key = user.duo_pro_cache_key_formatted
        Rails.cache.write(cache_key, false, expires_in: 1.hour)

        expect { subject }.to change { Rails.cache.read(cache_key) }.from(false).to(nil)
      end
    end

    shared_examples 'error response' do |error|
      it 'does not create new records' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          log_params.merge(
            {
              message: 'User AddOn assignment creation failed',
              error: error,
              error_code: 422
            }
          )
        )

        expect { subject }.not_to change { add_on_purchase.assigned_users.count }
        expect(response.errors).to include(error)
      end

      it 'does not enqueue the seat assignment email' do
        expect { subject }.not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_pro_email)
      end
    end

    it_behaves_like 'success response'

    context 'when user is already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it 'does not create new record' do
        expect { response }.not_to change { add_on_purchase.assigned_users.count }
        expect(response).to be_success
      end

      it 'does not enqueue the seat assignment email' do
        expect { response }.not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_pro_email)
      end
    end

    context 'when seats are not available' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: create(:user))
      end

      it_behaves_like 'error response', 'NO_SEATS_AVAILABLE'
    end

    context 'when user is not eligible' do
      let(:user) { create(:user, :bot) }

      it_behaves_like 'error response', 'INVALID_USER_MEMBERSHIP'
    end

    context 'when user is eligible' do
      let(:user) { create(:user) }

      it_behaves_like 'success response'
    end

    context 'with resource locking' do
      before do
        add_on_purchase.update!(quantity: 1)
      end

      it 'prevents from double booking assignment' do
        users = create_list(:user, 3)

        expect(add_on_purchase.assigned_users.count).to eq(0)

        users.map do |user|
          Thread.new do
            described_class.new(
              add_on_purchase: add_on_purchase,
              user: user
            ).execute
          end
        end.each(&:join)

        expect(add_on_purchase.assigned_users.count).to eq(1)
      end

      context 'when NoSeatsAvailableError is raised' do
        let(:service_instance) { described_class.new(add_on_purchase: add_on_purchase, user: user) }

        subject(:response) { service_instance.execute }

        it 'handes the error correctly' do
          # fill up the available seats
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase)

          # Mock first call to return true to pass the validate phase
          expect(service_instance).to receive(:seats_available?).and_return(true)
          expect(service_instance).to receive(:seats_available?).and_call_original

          expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
            an_instance_of(described_class::NoSeatsAvailableError),
            log_params.merge({ message: 'User AddOn assignment creation failed' })
          )

          expect { response }.not_to raise_error
          expect(response.errors).to include('NO_SEATS_AVAILABLE')
        end
      end
    end

    context 'with duo assignment emails' do
      context 'when add on is not duo related' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on) }

        it 'does not send a duo pro email' do
          expect { response }
            .not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_pro_email)
        end

        it 'does not send a duo enterprise email' do
          expect { response }
            .not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_enterprise_email)
        end
      end

      context 'when add on is duo pro' do
        it 'sends seat assignment email' do
          expect { response }.to have_enqueued_mail(
            GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_pro_email).with(user)
        end

        it 'creates duo access granted todo' do
          expect { response }.to change { user.todos.count }.by(1)
          expect(user.todos.last.action).to eq(::Todo::DUO_PRO_ACCESS_GRANTED)
        end

        context 'when feature flag `sm_duo_seat_assignment_email` is not enabled' do
          before do
            stub_feature_flags(sm_duo_seat_assignment_email: false)
          end

          it 'does not enqueue the seat assignment email' do
            expect do
              response
            end.not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_pro_email)
          end
        end
      end

      context 'when add on is duo enterprise' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on) }

        it 'sends seat assignment email' do
          expect { response }.to have_enqueued_mail(
            GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_enterprise_email).with(user)
        end

        it 'creates duo access granted todo' do
          expect { response }.to change { user.todos.count }.by(1)
          expect(user.todos.last.action).to eq(::Todo::DUO_ENTERPRISE_ACCESS_GRANTED)
        end

        context 'when feature flag `sm_duo_seat_assignment_email` is not enabled' do
          before do
            stub_feature_flags(sm_duo_seat_assignment_email: false)
          end

          it 'does not enqueue the seat assignment email' do
            expect do
              response
            end.not_to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, :duo_enterprise_email)
          end
        end
      end
    end
  end
end
