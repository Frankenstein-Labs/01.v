# frozen_string_literal: true

RSpec.shared_examples Integrations::Base::AmazonQ do
  subject(:integration) { create(:amazon_q_integration, auto_review_enabled: auto_review_enabled) }

  let_it_be(:auto_review_enabled, freeze: false) { true }

  describe 'Validations' do
    context 'when active' do
      it { is_expected.to validate_presence_of(:role_arn) }
      it { is_expected.to validate_length_of(:role_arn).is_at_most(2048) }
      it { is_expected.to validate_presence_of(:availability) }

      describe '#role_arn' do
        it 'can be changed' do
          integration.role_arn = "changed"

          expect(integration).to be_valid
        end

        context 'when integration is project-level' do
          subject(:integration) { create(:amazon_q_integration, project: create(:project), instance: false) }

          it 'cannot be changed' do
            integration.role_arn = "changed"

            expect(integration).not_to be_valid
          end
        end

        context 'when integration is group-level' do
          subject(:integration) { create(:amazon_q_integration, group: create(:group), instance: false) }

          it 'cannot be changed' do
            integration.role_arn = "changed"

            expect(integration).not_to be_valid
          end
        end
      end

      describe '#availability' do
        it 'validates that the value is one of the defined options' do
          is_expected.to validate_inclusion_of(
            :availability
          ).in_array(%w[default_on default_off never_on])
            .with_message('must be one of: default_on, default_off, never_on')
        end
      end
    end

    context 'when inactive' do
      before do
        integration.active = false
      end

      it { is_expected.not_to validate_presence_of(:role_arn) }
      it { is_expected.not_to validate_presence_of(:availability) }
      it { is_expected.not_to validate_inclusion_of(:availability).in_array(%w[default_on default_off never_on]) }
    end

    describe '#auto_review_enabled' do
      context 'when integration is not available' do
        before do
          integration.availability = 'default_off'
        end

        it 'validates that the integration must be available' do
          is_expected.to validate_inclusion_of(
            :auto_review_enabled
          ).in_array([false]).with_message("integration must be available")
        end
      end

      it 'allows auto_review_enabled for available integrations' do
        integration = build(
          :amazon_q_integration,
          availability: "default_on",
          auto_review_enabled: true,
          organization: create(:organization)
        )

        expect(integration).to be_valid
      end
    end

    describe 'web hook events' do
      using RSpec::Parameterized::TableSyntax

      where(:merge_requests_events, :pipeline_events, :auto_review_enabled_value, :errors) do
        pipeline_events_error = 'Pipeline events must be equal to auto_review_enabled'
        merge_requests_events_error = 'Merge requests events must be equal to auto_review_enabled'

        true  | true  | true  | []
        true  | false | true  | [pipeline_events_error]
        false | true  | true  | [merge_requests_events_error]
        true  | true  | false | [pipeline_events_error, merge_requests_events_error]
      end

      with_them do
        it 'validates that merge request and pipeline events equal to auto_review_enabled' do
          integration = build(:amazon_q_integration,
            auto_review_enabled: auto_review_enabled_value,
            merge_requests_events: merge_requests_events, pipeline_events: pipeline_events,
            organization: create(:organization)
          )

          expect(integration.valid?).to eq(errors.blank?)
          expect(integration.errors.full_messages).to match_array(errors)
        end
      end
    end
  end

  describe '#execute' do
    let_it_be(:user, freeze: false) { create(:user) }

    it 'does not send events if user is not passed' do
      expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

      integration.execute({ some_data: :data })
    end

    context 'when a user can be found', :request_store do
      using RSpec::Parameterized::TableSyntax

      where(:object_kind, :event_id) do
        :pipeline | 'Pipeline Hook'
        :merge_request | 'Merge Request Hook'
      end

      with_them do
        it 'sends an event to amazon q' do
          data = { object_kind: object_kind, user: { id: user.id } }

          ::Ai::Setting.for_organization(integration.send(:settings_organization))
            .update!(amazon_q_role_arn: 'role-arn')

          expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |instance|
            expect(instance).to receive(:create_event).with(
              payload: { source: :web_hook, data: data },
              role_arn: 'role-arn',
              event_id: event_id
            )
          end

          integration.execute(data)
        end
      end

      context 'and the user is a composite identity' do
        let_it_be(:composite_identity_user, freeze: false) do
          create(:user, :service_account, composite_identity_enforced: true)
        end

        let(:data) { { object_kind: :pipeline, user: { id: composite_identity_user.id } } }

        it 'does not send events if user is not passed' do
          expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

          integration.execute(data)
        end

        context 'and it is scoped to a user' do
          before do
            ::Gitlab::Auth::Identity.fabricate(composite_identity_user).link!(user)
          end

          it 'sends an event to amazon q' do
            ::Ai::Setting.for_organization(integration.send(:settings_organization))
              .update!(amazon_q_role_arn: 'role-arn')

            expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |instance|
              expect(instance).to receive(:create_event).with(
                payload: { source: :web_hook, data: data },
                role_arn: 'role-arn',
                event_id: 'Pipeline Hook'
              )
            end

            integration.execute(data)
          end

          context 'when auto_review_enabled is disabled' do
            let_it_be(:auto_review_enabled, freeze: false) { false }

            it 'does not send events if user is not passed' do
              expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

              integration.execute(data)
            end
          end
        end
      end
    end
  end

  describe '#auto_review_enabled' do
    it 'changes merge request and pipeline events' do
      expect do
        integration.update!(auto_review_enabled: false)
      end.to change { integration.merge_requests_events }.from(true).to(false)
          .and change { integration.pipeline_events }.from(true).to(false)
    end
  end

  describe '#sections' do
    it 'returns section configuration' do
      expect(integration.sections).to eq([{
        type: 'amazon_q',
        title: 'Configure GitLab Duo with Amazon Q',
        description: described_class.help,
        plan: 'ultimate'
      }])
    end
  end

  describe '#editable?' do
    it 'returns false' do
      expect(integration.editable?).to be false
    end
  end

  describe 'class methods' do
    describe '.title' do
      it 'returns the correct title' do
        expect(described_class.title).to eq('Amazon Q')
      end
    end

    describe '.description' do
      it 'returns the correct description' do
        expect(described_class.description).to eq(
          'Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java.'
        )
      end
    end

    describe '.help' do
      it 'returns a valid help URL' do
        expect(described_class.help).to match(%r{http.+duo_amazon_q/index\.md})
      end

      it 'includes relevant information' do
        expect(described_class.help).to include(described_class.description)
        expect(described_class.help).to include(
          'GitLab Duo with Amazon Q is separate from GitLab Duo Pro and Enterprise.'
        )
      end
    end

    describe '.to_param' do
      it 'returns the correct parameter name' do
        expect(described_class.to_param).to eq('amazon_q')
      end
    end

    describe '.supported_events' do
      it 'returns supported events for web hooks' do
        expect(described_class.supported_events).to eq(%w[merge_request pipeline])
      end
    end
  end
end
