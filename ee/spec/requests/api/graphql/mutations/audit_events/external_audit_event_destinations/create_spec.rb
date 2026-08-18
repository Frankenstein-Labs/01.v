# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:destination_url) { 'https://gitlab.com/example/testendpoint' }
  let_it_be(:destination_name) { 'My Destination' }
  let_it_be(:verification_token) { 'secret-verification-token' }

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:external_audit_event_destination_create, input) }
  let(:mutation_response) { graphql_mutation_response(:external_audit_event_destination_create) }

  let(:input) do
    {
      groupPath: group.full_path,
      destinationUrl: destination_url,
      name: destination_name
    }
  end

  let(:invalid_input) do
    {
      groupPath: group.full_path,
      destinationUrl: 'ftp://gitlab.com/example/testendpoint'
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'creates an audit event' do
    it 'audits the creation' do
      expect { subject }
        .to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last.details[:custom_message]).to eq("Create event streaming destination https://gitlab.com/example/testendpoint")
    end
  end

  shared_examples 'a mutation that does not create a destination' do
    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEvents::ExternalAuditEventDestination.count }
    end

    it 'does not audit the creation' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    subject { post_graphql_mutation(mutation, current_user: owner) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
      end

      it 'resolves group by full path' do
        expect(::Group).to receive(:find_by_full_path).with(group.full_path).twice

        subject
      end

      it 'creates the destination' do
        expect { subject }
          .to change { AuditEvents::ExternalAuditEventDestination.count }.by(1)

        destination = AuditEvents::ExternalAuditEventDestination.last
        expect(destination.group).to eq(group)
        expect(destination.destination_url).to eq(destination_url)
        expect(destination.name).not_to be_empty
        expect(destination.verification_token).to be_present
      end

      context 'when overriding default name' do
        let(:name) { 'My Destination' }

        let(:input) do
          {
            groupPath: group.full_path,
            destinationUrl: destination_url,
            name: name
          }
        end

        it 'creates the destination' do
          expect { subject }
            .to change { AuditEvents::ExternalAuditEventDestination.count }.by(1)

          destination = AuditEvents::ExternalAuditEventDestination.last
          expect(destination.group).to eq(group)
          expect(destination.destination_url).to eq(destination_url)
          expect(destination.name).to eq(name)
          expect(destination.verification_token).to be_present
        end
      end

      it_behaves_like 'creates an audit event'

      it_behaves_like 'creates a streaming destination',
        AuditEvents::ExternalAuditEventDestination do
        let(:attributes) do
          {
            legacy: {
              destination_url: destination_url,
              name: destination_name,
              namespace_id: group.id
            },
            streaming: {
              "url" => destination_url
            }
          }
        end
      end

      context 'when overriding verification token' do
        let_it_be(:verification_token) { 'a' * 24 }

        let(:input) do
          {
            groupPath: group.full_path,
            destinationUrl: destination_url,
            verificationToken: verification_token
          }
        end

        it 'creates the destination' do
          expect { subject }
            .to change { AuditEvents::ExternalAuditEventDestination.count }.by(1)

          destination = AuditEvents::ExternalAuditEventDestination.last
          expect(destination.group).to eq(group)
          expect(destination.verification_token).to eq(verification_token)
          expect(destination.destination_url).to eq(destination_url)
        end

        it_behaves_like 'creates an audit event'

        context 'when verification token is invalid' do
          let(:mutation) { graphql_mutation(:external_audit_event_destination_create, invalid_input) }

          context 'when verification token is too short' do
            let(:invalid_input) do
              {
                groupPath: group.full_path,
                destinationUrl: destination_url,
                verificationToken: 'a'
              }
            end

            it 'returns correct errors' do
              post_graphql_mutation(mutation, current_user: owner)

              expect(graphql_errors).not_to be_empty
              expect(graphql_errors.first['message']).to match(/Verification token is too short/)
            end

            it_behaves_like 'a mutation that does not create a destination'
          end

          context 'when verification token is too long' do
            let(:invalid_input) do
              {
                groupPath: group.full_path,
                destinationUrl: destination_url,
                verificationToken: 'a' * 25
              }
            end

            it 'returns correct errors' do
              post_graphql_mutation(mutation, current_user: owner)

              expect(graphql_errors).not_to be_empty
              expect(graphql_errors.first['message']).to match(/Verification token is too long/)
            end

            it_behaves_like 'a mutation that does not create a destination'
          end
        end
      end

      context 'when destination is invalid' do
        let(:mutation) { graphql_mutation(:external_audit_event_destination_create, invalid_input) }

        it 'returns correct errors' do
          post_graphql_mutation(mutation, current_user: owner)

          expect(graphql_errors).not_to be_empty
          expect(graphql_errors.first['message']).to match(/Destination url is blocked: Only allowed schemes are http, https/)
        end

        it_behaves_like 'a mutation that does not create a destination'
      end

      context 'when group is a subgroup' do
        let_it_be(:group) { create(:group, :nested) }

        it_behaves_like 'a mutation that does not create a destination'
      end

      context 'when ActiveRecord::RecordInvalid exceptions occur' do
        context 'when limit is exceeded' do
          before do
            allow_next_instance_of(AuditEvents::ExternalAuditEventDestination) do |instance|
              allow(instance).to receive(:save!) do
                instance.errors.add(:base, 'Maximum number of external audit event destinations (5) exceeded')
                raise ActiveRecord::RecordInvalid, instance
              end
            end
          end

          it 'returns GraphQL error and does not log to Sentry' do
            expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

            post_graphql_mutation(mutation, current_user: owner)

            expect(graphql_errors).not_to be_empty
            expect(graphql_errors.first['message']).to match(/Maximum number of external audit event destinations/)
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when name is too long' do
          let(:input) do
            {
              groupPath: group.full_path,
              destinationUrl: destination_url,
              name: 'a' * 73 # Exceeds 72 character limit
            }
          end

          before do
            allow_next_instance_of(AuditEvents::ExternalAuditEventDestination) do |instance|
              allow(instance).to receive(:save!) do
                instance.errors.add(:name, 'is too long (maximum is 72 characters)')
                raise ActiveRecord::RecordInvalid, instance
              end
            end
          end

          it 'returns GraphQL error and does not log to Sentry' do
            expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

            post_graphql_mutation(mutation, current_user: owner)

            expect(graphql_errors).not_to be_empty
            expect(graphql_errors.first['message']).to match(/is too long/)
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not create the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEvents::ExternalAuditEventDestination.count }
    end
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:user) }

    before_all do
      group.add_owner(granular_token_user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
