# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FinishService, feature_category: :onboarding do
  let_it_be_with_reload(:user) { create(:user, onboarding_in_progress: true) }

  describe '#execute', :aggregate_failures do
    subject(:execute) { described_class.new(user).execute }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'updates onboarding_in_progress to false' do
        expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end

      context 'when initial attempt at update fails' do
        before do
          allow(user).to receive(:update).and_return(false)
        end

        it 'logs and performs a more forceful update' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(::Onboarding::StepUrlError),
            onboarding_status: user.onboarding_status.to_json,
            user_id: user.id
          )

          expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_success
        end

        context 'with project authorization errors' do
          let(:project) { build_stubbed(:project) }

          before do
            errors = ActiveModel::Errors.new(user).tap { |e| e.add(:project_authorizations, 'is invalid') }
            project_auth = build(:project_authorization, :reporter, project: project, user: user, is_unique: false)
            allow(project_auth).to receive(:errors).and_return(
              ActiveModel::Errors.new(project_auth).tap { |e| e.add(:access_level, 'is invalid') }
            )

            allow(user).to receive_messages(errors: errors, project_authorizations: [project_auth])
          end

          it 'logs error including project authorization details' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception) do |error|
              expect(error).to be_a(Onboarding::StepUrlError)
              message = "Failed initial attempt to finish onboarding with: Project authorizations is invalid. " \
                "Access level is invalid: project_id: #{project.id}, user_id: #{user.id}, access_level: 20, " \
                "is_unique: false."
              expect(error.message).to include(message)
            end

            expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_success
          end

          it 'limits project authorization error collection' do
            authorizations = Array.new(15) do
              auth = build(:project_authorization)
              allow(auth).to receive(:errors).and_return(
                ActiveModel::Errors.new(auth).tap { |e| e.add(:access_level, 'is invalid') }
              )
              auth
            end

            allow(user).to receive(:project_authorizations).and_return(authorizations)

            expect(Gitlab::ErrorTracking).to receive(:track_exception) do |error|
              expect(error).to be_a(Onboarding::StepUrlError)
              expect(error.message).to include('Project authorizations is invalid.')
              expect(error.message.scan(/Access level is invalid: project_id:/).count).to eq(10)
            end

            expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_success
          end
        end

        context 'when second attempt at update fails' do
          before do
            allow(user).to receive(:update_attribute).and_return(false)
          end

          it 'logs and returns an error' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(::Onboarding::StepUrlError),
              onboarding_status: user.onboarding_status.to_json,
              user_id: user.id
            )

            expect(Gitlab::ErrorTracking).to receive(:track_exception) do |error|
              expect(error).to be_a(Onboarding::StepUrlError)
              expect(error.message).to include('Failed final attempt to finish onboarding with:')
            end

            expect { execute }.not_to change { user.onboarding_in_progress }
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_error
          end
        end
      end
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect { execute }.not_to change { user.onboarding_in_progress }
        expect(user).to be_onboarding_in_progress
      end
    end
  end

  describe '#onboarding_attributes' do
    subject { described_class.new(user).onboarding_attributes }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to eq({ onboarding_in_progress: false }) }
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to eq({}) }
    end
  end

  describe '#enterprise_user_onboarding_attributes' do
    subject { described_class.new(user).enterprise_user_onboarding_attributes }

    before do
      stub_saas_features(onboarding: true)
    end

    context 'when user qualifies as onboarding' do
      it { is_expected.to eq({ onboarding_in_progress: false }) }
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to eq({}) }
    end

    context 'when user has a UAT test account email' do
      let(:user) { create(:user, onboarding_in_progress: true, email: 'user+uat@gitlab.com') }

      it { is_expected.to eq({}) }
    end

    context 'when user does not have a UAT test account email' do
      let(:user) { create(:user, onboarding_in_progress: true, email: 'employee@gitlab.com') }

      it { is_expected.to eq({ onboarding_in_progress: false }) }
    end
  end
end
