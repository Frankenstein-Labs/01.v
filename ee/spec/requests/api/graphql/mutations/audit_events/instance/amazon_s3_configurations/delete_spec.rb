# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete instance Amazon S3 configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:config, freeze: false) { create(:instance_amazon_s3_configuration) }
  let_it_be(:current_user) { create(:admin) }

  let(:mutation) { graphql_mutation(:audit_events_instance_amazon_s3_configuration_delete, id: global_id_of(config)) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_instance_amazon_s3_configuration_delete) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is admin' do
      it 'destroys the configuration' do
        expect { mutate }.to change { AuditEvents::Instance::AmazonS3Configuration.count }.by(-1)
      end

      it 'audits the deletion' do
        expected_hash = {
          name: 'instance_amazon_s3_configuration_deleted',
          author: current_user,
          scope: an_instance_of(Gitlab::Audit::InstanceScope),
          target: config,
          message: "Deleted Instance Amazon S3 configuration with name: #{config.name} bucket: " \
                   "#{config.bucket_name} and AWS region: #{config.aws_region}"
        }

        expect(Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_hash))

        mutate
      end

      context 'when there is an error during destroy' do
        before do
          expect_next_found_instance_of(AuditEvents::Instance::AmazonS3Configuration) do |config|
            allow(config).to receive(:destroy).and_return(false)
            errors = ActiveModel::Errors.new(config).tap { |e| e.add(:base, 'error message') }
            allow(config).to receive(:errors).and_return(errors)
          end
        end

        it 'does not destroy the configuration and returns the error' do
          expect { mutate }.not_to change { AuditEvents::Instance::AmazonS3Configuration.count }

          expect(mutation_response).to include('errors' => ['error message'])
        end
      end

      context 'when paired destination exists' do
        let(:paired_model) do
          create(:audit_events_instance_external_streaming_destination, :aws, legacy_destination_ref: config.id)
        end

        it_behaves_like 'deletes paired destination', :config
      end
    end

    context 'when current user is not admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
