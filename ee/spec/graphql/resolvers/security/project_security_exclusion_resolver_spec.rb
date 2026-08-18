# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ProjectSecurityExclusionResolver, feature_category: :secret_detection do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:active_exclusion) { create(:project_security_exclusion, :with_rule, project: project) }
    let_it_be(:inactive_exclusion) { create(:project_security_exclusion, :with_raw_value, :inactive, project: project) }

    it do
      expect(described_class).to have_nullable_graphql_type(
        Types::Security::ProjectSecurityExclusionType.connection_type
      )
    end

    context 'when the feature is not licensed' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          security_exclusions
        end
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(security_exclusions: true)
      end

      context 'when resolving multiple security exclusions' do
        let(:args) { {} }

        subject(:resolver) { sync(security_exclusions(**args)) }

        context 'for a role that can read security exclusions' do
          before_all do
            project.add_maintainer(user)
          end

          it 'calls ProjectSecurityExclusionsFinder with correct arguments' do
            finder = instance_double(
              ::Security::ProjectSecurityExclusionsFinder,
              execute: [active_exclusion, inactive_exclusion]
            )

            expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
              .with(user, project: project, params: {})
              .and_return(finder)

            resolver
          end

          it 'returns all exclusions when no arguments are provided' do
            expect(resolver).to contain_exactly(active_exclusion, inactive_exclusion)
          end

          context 'when filtering by scanner' do
            let(:args) { { scanner: 'secret_push_protection' } }

            it 'passes the scanner argument to the finder' do
              expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
                .with(user, project: project, params: hash_including(scanner: 'secret_push_protection'))
                .and_call_original

              expect(resolver).to contain_exactly(active_exclusion, inactive_exclusion)
            end
          end

          context 'when filtering by type' do
            let(:args) { { type: 'raw_value' } }

            it 'passes the type argument to the finder' do
              expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
                .with(user, project: project, params: hash_including(type: 'raw_value'))
                .and_call_original

              expect(resolver).to contain_exactly(inactive_exclusion)
            end
          end

          context 'when filtering by active status' do
            let(:args) { { active: true } }

            it 'passes the status argument to the finder' do
              expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
                .with(user, project: project, params: hash_including(active: true))
                .and_call_original

              expect(resolver).to contain_exactly(active_exclusion)
            end
          end
        end

        context 'for a role that cannot read security exclusions' do
          before_all do
            project.add_reporter(user)
          end

          it 'returns no exclusions' do
            expect(resolver).to be_empty
          end
        end
      end

      context 'when resolving a single security exclusion' do
        subject { sync(single_security_exclusion(id: gid)) }

        context 'for a role that can read security exclusions' do
          before_all do
            project.add_maintainer(user)
          end

          context 'when the security exclusion exists' do
            let(:gid) { active_exclusion.to_global_id }

            it { is_expected.to eq active_exclusion }
          end

          context 'when the security exclusion does not exist' do
            let(:gid) do
              Gitlab::GlobalId.as_global_id(non_existing_record_id, model_name: 'Security::ProjectSecurityExclusion')
            end

            it { is_expected.to be_nil }
          end
        end

        context 'for a role that cannot read security exclusions' do
          before_all do
            project.add_reporter(user)
          end

          let(:gid) { active_exclusion.to_global_id }

          it { is_expected.to be_nil }
        end
      end
    end
  end

  private

  def security_exclusions(**args)
    resolve(described_class, obj: project, ctx: { current_user: user }, args: args)
  end

  def single_security_exclusion(**args)
    resolve(described_class.single, obj: project, ctx: { current_user: user }, args: args)
  end
end
