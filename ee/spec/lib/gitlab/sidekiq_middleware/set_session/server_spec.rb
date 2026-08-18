# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware::SetSession::Server, feature_category: :shared do
  let(:worker) { instance_double(ApplicationWorker) }
  let(:job) { {} }
  let(:queue) { 'default' }
  let(:server) { described_class.new }

  describe '#call' do
    def call!(&block)
      block ||= -> {}
      subject.call(worker, job, queue, &block)
    end

    context 'when job has set_session_id' do
      let(:session_id) { 'session_id' }
      let(:session) { { 'key' => 'value' } }
      let(:job) { { 'set_session_id' => session_id } }

      it 'sets the session and yields' do
        expect(ActiveSession).to receive(:sessions_from_ids).with([session_id]).and_return([session])
        expect(Gitlab::Session).to receive(:with_session).with(session.merge("set_session_id" => session_id)).and_yield

        call!
      end

      it 'when session is not found' do
        expect(ActiveSession).to receive(:sessions_from_ids).with([session_id]).and_return([])
        expect(Gitlab::Session).to receive(:with_session).with({ "set_session_id" => session_id }).and_yield

        call!
      end

      context 'when set_session_id is nil' do
        let(:session_id) { nil }

        it 'sets empty session and yields' do
          expect(ActiveSession).not_to receive(:sessions_from_ids)
          expect(Gitlab::Session).to receive(:with_session).with({ "set_session_id" => session_id }).and_yield

          call!
        end
      end
    end

    context 'when set_session_id key is absent' do
      it 'yields without setting the session' do
        expect(Gitlab::Session).not_to receive(:with_session)

        call!
      end
    end
  end
end
