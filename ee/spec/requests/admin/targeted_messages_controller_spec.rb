# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::TargetedMessagesController, :enable_admin_mode, :saas, feature_category: :acquisition do
  let_it_be(:admin) { create(:admin) }
  let(:targeted_message) { build(:targeted_message) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    it 'renders index template' do
      get admin_targeted_messages_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:index)
    end
  end

  describe 'GET #new' do
    it 'renders new template' do
      get new_admin_targeted_message_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    before do
      targeted_message.save!
    end

    it 'renders edit template' do
      get edit_admin_targeted_message_path(targeted_message)
      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
    let(:invalid_namespace_ids) { [] }
    let(:targeted_message_params) do
      { targeted_message: targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
    end

    let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
    let(:csv_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      fixture_file_upload(temp_file.path, 'text/csv')
    end

    after do
      csv_file.unlink
    end

    context 'when successful' do
      it 'returns ok status' do
        expect do
          post admin_targeted_messages_path, params: targeted_message_params
        end.to change { Notifications::TargetedMessage.count }.by(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(Notifications::TargetedMessage.last.roles).to eq([])
      end

      context 'with roles' do
        let(:targeted_message_params) do
          {
            targeted_message: targeted_message.attributes.merge(
              namespace_ids_csv: csv_file,
              roles: [Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER]
            )
          }
        end

        it 'creates a targeted message with roles' do
          expect do
            post admin_targeted_messages_path, params: targeted_message_params
          end.to change { Notifications::TargetedMessage.count }.by(1)

          expect(response).to have_gitlab_http_status(:ok)

          expect(Notifications::TargetedMessage.last.roles).to contain_exactly(
            Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER
          )
        end
      end
    end

    context 'when there are invalid namespace ids' do
      let(:invalid_namespace_ids) { [non_existing_record_id] }

      it 'returns ok status with redirect_to' do
        expect do
          post admin_targeted_messages_path, params: targeted_message_params
        end.to change { Notifications::TargetedMessage.count }.by(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['redirect_to']).to eq(
          edit_admin_targeted_message_path(Notifications::TargetedMessage.last)
        )
      end
    end

    context 'when on failure' do
      let(:targeted_message_params) do
        { targeted_message: { target_type: '', namespace_ids_csv: csv_file } }
      end

      it 'returns unprocessable entity status with error messages' do
        expect { post admin_targeted_messages_path, params: targeted_message_params }.not_to change {
          Notifications::TargetedMessage.count
        }

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to be_a(Hash)
        expect(json_response['message']['target_type']).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
    let(:invalid_namespace_ids) { [] }
    let(:targeted_message_params) do
      { targeted_message: targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
    end

    let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
    let(:temp_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      temp_file
    end

    let(:csv_file) { fixture_file_upload(temp_file.path, 'text/csv') }

    after do
      temp_file.unlink
    end

    before do
      targeted_message.save!
    end

    context 'when successful' do
      it 'returns ok status' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when there are invalid namespace ids' do
      let(:invalid_namespace_ids) { [non_existing_record_id] }

      it 'returns ok status with redirect_to' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['redirect_to']).to eq(
          edit_admin_targeted_message_path(targeted_message)
        )
      end
    end

    context 'when on failure' do
      let(:targeted_message_params) do
        { targeted_message: { target_type: '', namespace_ids_csv: csv_file } }
      end

      it 'returns unprocessable entity status with error messages' do
        patch admin_targeted_message_path(targeted_message), params: targeted_message_params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to be_a(Hash)
        expect(json_response['message']['target_type']).to be_present
      end
    end
  end

  describe 'DELETE #destroy' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:user) { create(:user) }

    before do
      targeted_message.save!
    end

    it 'schedules the targeted message for deletion' do
      expect(Notifications::TargetedMessages::DestroyWorker).to receive(:perform_async).with(targeted_message.id)

      delete admin_targeted_message_path(targeted_message)

      expect(response).to redirect_to(admin_targeted_messages_path)
      expect(flash[:notice]).to eq(format(
        s_('TargetedMessages|Scheduled deletion of targeted message with id: %{id}.'), id: targeted_message.id))
    end

    it 'does not delete the targeted message immediately' do
      expect do
        delete admin_targeted_message_path(targeted_message)
      end.not_to change { Notifications::TargetedMessage.count }
    end

    context 'when targeted message does not exist' do
      it 'returns 404' do
        delete admin_targeted_message_path(non_existing_record_id)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
