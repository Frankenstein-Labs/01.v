# frozen_string_literal: true

RSpec.shared_examples "it requires a valid license" do
  context "when licensed feature is unavailable" do
    let(:current_user) { admin }

    before do
      stub_licensed_features(custom_roles: false)
    end

    it "returns forbidden error" do
      subject

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end
end

RSpec.shared_examples "getting member roles" do
  it_behaves_like "it requires a valid license"

  context "when current user is nil" do
    it "returns unauthorized error" do
      get_member_roles

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  context "when current user is not authorized" do
    let(:current_user) { user }

    it "returns forbidden error" do
      get_member_roles

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  context "when current user is authorized" do
    let(:current_user) { authorized_user }

    it "returns associated member roles" do
      get_member_roles

      expect(response).to have_gitlab_http_status(:ok)

      expect(json_response).to(match_array(expected_member_roles))
    end
  end
end

RSpec.shared_examples "creating member role" do
  it_behaves_like "it requires a valid license"

  context "when current user is nil" do
    it "returns unauthorized error" do
      create_member_role

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  context "when current user is unauthorized" do
    let(:current_user) { user }

    it "does not allow less privileged user to add member roles" do
      expect { create_member_role }.not_to change { member_roles.count }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  context "when current user is authorized" do
    let(:current_user) { authorized_user }

    context "when name param is passed" do
      it "returns the newly created member role", :aggregate_failures do
        expect { create_member_role }.to change { member_roles.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)

        expect(json_response).to include(expected_json_response)
      end
    end

    context "when no name param is passed" do
      before do
        params.delete('name')
      end

      it "returns newly created member role with a default name", :aggregate_failures do
        expect { create_member_role }.to change { member_roles.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)

        expected_json_response['name'] = default_role_name

        expect(json_response).to include(expected_json_response)
      end
    end

    context "when no permissions is true" do
      before do
        params[role_permission] = false
      end

      it "returns a 400 error", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)

        expect(json_response['message']).to match(/Cannot create a member role with no enabled permissions/)
      end
    end

    context "when there are validation errors" do
      before do
        allow_next_instance_of(MemberRole) do |instance|
          instance.errors.add(:base, 'validation error')

          allow(instance).to receive(:valid?).and_return(false)
        end
      end

      it "returns a 400 error with an error message", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('validation error')
      end
    end
  end
end

RSpec.shared_examples "deleting member role" do
  it_behaves_like "it requires a valid license"

  context "when current user is nil" do
    it "returns unauthorized error" do
      delete_member_role

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  context "when current user is not authorized" do
    let(:current_user) { user }

    it "does not remove the member role" do
      expect { delete_member_role }.not_to change { member_roles.count }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  context "when current user is authorized" do
    let(:current_user) { authorized_user }

    it "deletes member role", :aggregate_failures do
      expect { delete_member_role }.to change { member_roles.count }.by(-1)

      expect(response).to have_gitlab_http_status(:no_content)
    end

    context "when invalid member role is passed" do
      let(:member_role_id) { non_existing_record_id }

      it "returns 404 error", :aggregate_failures do
        expect { delete_member_role }.not_to change { member_roles.count }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Member Role Not Found')
      end
    end

    context "when there is an error deleting the role" do
      before do
        allow_next_instance_of(::MemberRoles::DeleteService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error'))
        end
      end

      it "returns 400 error" do
        delete_member_role

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end
