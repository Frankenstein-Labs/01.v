# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TrainingUrlsService, feature_category: :vulnerability_management do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:filename, freeze: false) { nil }
  let_it_be(:vulnerability, freeze: false) { create(:vulnerability, :with_findings, project: project) }

  let_it_be(:identifier, freeze: false) do
    create(:vulnerabilities_identifier,
      project: project,
      external_type: 'cwe',
      external_id: 2,
      name: 'cwe-2')
  end

  let_it_be(:identifier_external_id, freeze: false) do
    "[#{identifier.external_type}]-[#{identifier.external_id}]-[#{identifier.name}]"
  end

  subject { described_class.new(project, identifier_external_ids, filename).execute }

  context 'when there is no identifier with cwe external type' do
    let(:identifier_external_ids) { [] }

    it 'returns empty list' do
      is_expected.to be_empty
    end
  end

  context 'with identifiers with cwe external type' do
    let(:identifier_external_ids) { [identifier_external_id] }

    context 'when there is no training provider enabled for project' do
      it 'returns empty list' do
        is_expected.to be_empty
      end
    end

    context 'when there is training provider enabled for project' do
      before do
        create(:security_training, :primary, :kontra, project: project)
        project.reload
      end

      it 'calls Security::TrainingProviders::KontraUrlService#execute' do
        expect_next_instance_of(::Security::TrainingProviders::KontraUrlService) do |service|
          expect(service).to receive(:execute)
        end

        subject
      end

      context 'when training url has been reactively cached' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlService) do |service|
            allow(service).to receive(:response_url).and_return(url: 'http://test.host/test')
          end
        end

        it 'returns training urls list with status completed' do
          is_expected.to match_array(
            [{ name: 'Kontra', url: 'http://test.host/test', status: 'completed', identifier: identifier.name }]
          )
        end

        ::Security::TrainingUrlsService::EXTENSION_LANGUAGE_MAP.each do |extension, language|
          context "when a filename with extension .#{extension} is provided" do
            let(:filename) { "code.#{extension}" }
            let(:training_provider) do
              ::Security::TrainingProviders::KontraUrlService.new(project, identifier_external_id, language)
            end

            before do
              allow(::Security::TrainingProviders::KontraUrlService).to receive(:new)
                                                                        .with(project, identifier.external_id, language)
                                                                        .and_return(training_provider)
              allow(training_provider).to receive(:response_url).and_return(url: 'http://test.host/test')
              allow(training_provider).to receive(:execute)
            end

            it "requests urls with the language #{language}" do
              is_expected.to match_array(
                [{
                  name: 'Kontra',
                  url: 'http://test.host/test',
                  status: 'completed',
                  identifier: identifier.name
                }]
              )
            end
          end
        end
      end

      context 'when training url has not yet been reactively cached' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlService) do |service|
            allow(service).to receive(:response_url).and_return(nil)
          end
        end

        it 'returns training urls list with status pending' do
          is_expected.to match_array([{ name: 'Kontra', url: nil, status: 'pending' }])
        end

        context 'when a filename is provided' do
          let_it_be(:filename, freeze: false) { 'code.rb' }

          it 'returns training urls list with status pending' do
            is_expected.to match_array([{ name: 'Kontra', url: nil, status: 'pending' }])
          end
        end
      end

      context 'when training urls service returns nil url' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlService) do |service|
            allow(service).to receive(:response_url).and_return(url: nil)
          end
        end

        it 'returns empty list when training urls service returns nil' do
          is_expected.to be_empty
        end
      end
    end
  end
end
