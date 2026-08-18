# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker, feature_category: :acquisition do
  let_it_be(:organization) { create(:organization) }

  describe '#perform' do
    let_it_be(:users) { create_list(:user, 3) }
    let(:duo_enabled) { true }

    subject(:perform) { described_class.new.perform(organization.id) }

    before do
      create(:ai_settings, organization: organization, duo_core_features_enabled: duo_enabled)
    end

    context 'when duo core features are enabled' do
      it 'creates todos for eligible users' do
        expect { perform }.to change { Todo.count }.by(3)

        expect(Todo.all.pluck(:user_id)).to match_array(users.map(&:id))
      end

      context 'when the job was enqueued without an organization ID' do
        subject(:perform) { described_class.new.perform }

        before do
          allow(::Organizations::Organization).to receive(:default_organization).and_return(organization)
        end

        it 'creates todos using the default organization settings' do
          expect { perform }.to change { Todo.count }.by(3)
        end
      end

      context 'when the organization does not exist' do
        subject(:perform) { described_class.new.perform(non_existing_record_id) }

        it 'does not create todos' do
          expect { perform }.not_to change { Todo.count }
        end
      end

      context 'when duo core features are disabled during processing' do
        before do
          allow_next_instance_of(GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder) do |finder|
            allow(finder).to receive(:execute).and_wrap_original do |method|
              ::Ai::Setting.find_by!(organization: organization).update!(duo_core_features_enabled: false)
              method.call
            end
          end
        end

        it 'stops processing batches' do
          expect { perform }.not_to change { Todo.count }
        end
      end
    end

    context 'when duo core features are disabled' do
      let(:duo_enabled) { false }

      it 'does not create todos' do
        expect { perform }.not_to change { Todo.count }
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [organization.id] }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed
end
