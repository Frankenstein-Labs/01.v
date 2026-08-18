# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::GitlabCom::DuoCoreTodoNotificationWorker, feature_category: :acquisition do
  describe '#perform' do
    let_it_be(:users) { create_list(:user, 3) }
    let_it_be_with_reload(:namespace) { create(:group, developers: users) }
    let(:namespace_id) { namespace.id }

    subject(:perform) { described_class.new.perform(namespace_id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [namespace_id] }
    end

    it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

    context 'when duo core features are enabled' do
      context 'when namespace exists' do
        before_all do
          namespace.namespace_settings.update!(duo_core_features_enabled: true)
        end

        it 'creates todos for eligible users' do
          create(:user) # unrelated user who should not receive a todo

          expect { perform }.to change { Todo.count }.by(3)

          expect(Todo.all.pluck(:user_id)).to match_array(users.map(&:id))
        end
      end

      context 'when namespace does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it 'does not create todos and exist gracefully' do
          expect { perform }.not_to change { Todo.count }
        end
      end
    end

    context 'when duo core features are disabled' do
      before_all do
        namespace.namespace_settings.update!(duo_core_features_enabled: false)
      end

      it 'does not create todos' do
        expect { perform }.not_to change { Todo.count }
      end
    end
  end
end
