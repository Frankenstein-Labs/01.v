# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Applications::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { name: 'my-application', description: 'a description' } }

  subject(:result) do
    described_class.new(parent: organization, current_user: current_user, params: params).execute
  end

  describe '#execute' do
    it 'returns a success response with the persisted application' do
      expect { result }.to change { ::Cd::Application.count }.by(1)

      application = result.payload[:application]
      expect(result).to be_success
      expect(application).to be_persisted
      expect(application).to have_attributes(
        organization: organization,
        name: 'my-application',
        description: 'a description'
      )
    end

    context 'when services are provided' do
      let(:params) do
        super().merge(services: [{ name: 'web', description: 'Web service' }, { name: 'worker' }])
      end

      it 'creates the application together with its services' do
        expect { result }
          .to change { ::Cd::Application.count }.by(1)
          .and change { ::Cd::Service.count }.by(2)

        expect(result).to be_success
        expect(result.payload[:application].services.pluck(:name)).to contain_exactly('web', 'worker')
      end

      it 'does not load the organization once per service' do
        recorder = ActiveRecord::QueryRecorder.new do
          described_class.new(parent: organization, current_user: current_user,
            params: { name: 'app-many', services: [{ name: 's1' }, { name: 's2' }, { name: 's3' }] }).execute
        end

        org_queries = recorder.log.count { |query| query.include?('FROM "organizations"') }
        expect(org_queries).to be <= 1
      end

      context 'when a service is invalid' do
        let(:params) { super().merge(services: [{ name: '' }]) }

        it 'rolls back and creates neither the application nor the services' do
          expect { result }
            .to not_change { ::Cd::Application.count }
            .and not_change { ::Cd::Service.count }

          expect(result).to be_error
          expect(result.message).to include("Name can't be blank")
        end
      end
    end

    context 'when services with artifact_sources are provided' do
      let(:params) do
        {
          name: 'my-application',
          services: [
            {
              name: 'web',
              artifact_sources: [
                { name: 'api', source_ref: 'registry.example.com/acme/api' },
                { name: 'worker', source_ref: 'registry.example.com/acme/worker' }
              ]
            }
          ]
        }
      end

      it 'creates the application, service, and nested artifact sources' do
        expect { result }
          .to change { ::Cd::Application.count }.by(1)
          .and change { ::Cd::Service.count }.by(1)
          .and change { ::Cd::ArtifactSource.count }.by(2)

        expect(result).to be_success

        web_service = result.payload[:application].services.find_by(name: 'web')
        expect(web_service.artifact_sources.pluck(:name, :source_ref)).to contain_exactly(
          ['api', 'registry.example.com/acme/api'],
          ['worker', 'registry.example.com/acme/worker']
        )
        expect(web_service.artifact_sources.first.organization).to eq(organization)
      end

      context 'when an artifact source is invalid' do
        let(:params) do
          super().tap do |p|
            p[:services][0][:artifact_sources] = [{ name: '', source_ref: 'registry.example.com/acme/api' }]
          end
        end

        it 'rolls back and creates neither the application, the service, nor the artifact source' do
          expect { result }
            .to not_change { ::Cd::Application.count }
            .and not_change { ::Cd::Service.count }
            .and not_change { ::Cd::ArtifactSource.count }

          expect(result).to be_error
          expect(result.message).to include("Name can't be blank")
        end
      end
    end

    context 'when name is blank' do
      let(:params) { super().merge(name: '') }

      it 'does not create an application and returns the error' do
        expect { result }.not_to change { ::Cd::Application.count }
        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
      end
    end

    context 'when name is already taken in the organization' do
      before do
        create(:cd_application, organization: organization, name: 'my-application')
      end

      it 'does not create an application and returns the error' do
        expect { result }.not_to change { ::Cd::Application.count }
        expect(result).to be_error
        expect(result.message).to include('Name has already been taken')
      end
    end
  end
end
