# frozen_string_literal: true

RSpec.shared_examples 'assigns tracked context to vulnerability finding' do
  describe 'tracked context assignment' do
    let(:default_branch) { 'main' }

    subject(:execute_service) { service_object.execute }

    shared_examples 'assigns tracked context correctly' do |expected_context_variable|
      it 'assigns the tracked context to the finding' do
        result = execute_result

        expect(result).to be_success
        finding = result.payload[:vulnerability].vulnerability_finding
        expect(finding.security_project_tracked_context_id).to eq(send(expected_context_variable).id)
      end

      it 'sets the security_project_tracked_context_id on vulnerability_read' do
        result = execute_result

        vulnerability_read = result.payload[:vulnerability].vulnerability_read
        expect(vulnerability_read.security_project_tracked_context_id).to eq(send(expected_context_variable).id)
      end
    end

    context 'when no tracked context information is provided' do
      context 'and the default tracked context does not exist' do
        let(:execute_result) { execute_service }

        it 'creates a default tracked context and assigns it' do
          expect { execute_service }.to change { Security::ProjectTrackedContext.count }.by(1)

          result = execute_service
          finding = result.payload[:vulnerability].vulnerability_finding
          tracked_context = Security::ProjectTrackedContext.last

          expect(tracked_context.context_name).to eq(project.default_branch_or_main)
          expect(tracked_context).to be_branch
          expect(tracked_context.is_default).to be(true)
          expect(tracked_context).to be_tracked
          expect(finding.security_project_tracked_context_id).to eq(tracked_context.id)
        end

        it 'sets the security_project_tracked_context_id on vulnerability_read' do
          result = execute_service
          tracked_context = Security::ProjectTrackedContext.last

          vulnerability_read = result.payload[:vulnerability].vulnerability_read
          expect(vulnerability_read.security_project_tracked_context_id).to eq(tracked_context.id)
        end
      end

      context 'and the default context already exists' do
        let!(:existing_default_context) do
          create(
            :security_project_tracked_context,
            :default,
            project: project,
            context_name: project.default_branch_or_main
          )
        end

        let(:execute_result) { execute_service }

        it 'does not create a new tracked context' do
          existing_default_context

          expect { execute_service }
            .not_to change { Security::ProjectTrackedContext.count }
        end

        it_behaves_like 'assigns tracked context correctly', :existing_default_context
      end
    end

    context 'when project_tracked_context_name and type are provided' do
      let(:context_name) { 'develop' }
      let(:context_type) { :branch }
      let(:service_params) do
        params.deep_merge(
          vulnerability: {
            project_tracked_context_name: context_name,
            project_tracked_context_type: context_type
          }
        )
      end

      context 'and the tracked context exists' do
        let!(:existing_context) do
          create(
            :security_project_tracked_context,
            :tracked,
            project: project,
            context_name: 'develop'
          )
        end

        let(:execute_result) { execute_service_with_params.call(service_params) }

        it 'does not create a new tracked context' do
          existing_context

          expect { execute_service_with_params.call(service_params) }
            .not_to change { Security::ProjectTrackedContext.count }
        end

        it_behaves_like 'assigns tracked context correctly', :existing_context
      end

      context 'and the tracked context does not exist' do
        it 'raises an error and does not create a tracked context' do
          expect { execute_service_with_params.call(service_params) }
            .to raise_error(::Vulnerabilities::CreateServiceBase::TrackedContextNotFoundError)
            .and not_change { Security::ProjectTrackedContext.count }
        end
      end
    end

    context 'when only project_tracked_context_name is provided' do
      let(:service_params) do
        params.deep_merge(
          vulnerability: {
            project_tracked_context_name: 'feature-branch'
          }
        )
      end

      it 'raises an error and does not create a tracked context' do
        expect { execute_service_with_params.call(service_params) }
          .to raise_error(ArgumentError)
          .and not_change { Security::ProjectTrackedContext.count }
      end
    end

    context 'when only context_type is provided' do
      let(:service_params) do
        params.deep_merge(
          vulnerability: {
            project_tracked_context_type: :branch
          }
        )
      end

      it 'raises ArgumentError' do
        expect { execute_service_with_params.call(service_params) }
          .to raise_error(ArgumentError, /project_tracked_context_name must be provided/)
          .and not_change { Security::ProjectTrackedContext.count }
      end
    end

    context 'when tracked context creation fails' do
      before do
        allow_next_instance_of(Security::ProjectTrackedContexts::FindOrCreateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Creation failed')
          )
        end
      end

      it 'does not create the vulnerability' do
        expect { execute_service }.to raise_error(::Vulnerabilities::CreateServiceBase::TrackedContextNotFoundError)
          .and not_change { Vulnerability.count }
      end
    end
  end
end
