# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Session, feature_category: :system_access do
  describe '.session_id_for_worker' do
    context 'when session is ActionDispatch::Request::Session' do
      let(:rack_session) { Rack::Session::SessionId.new('6919a6f1bb119dd7396fadc38fd18d0d') }
      let(:session) do
        ActionDispatch::Request::Session.allocate.tap do |session|
          allow(session).to receive_messages(id: rack_session,
            options: ActionDispatch::Request::Session::Options.new(nil, {})
          )
        end
      end

      it 'returns rack session private id' do
        described_class.with_session(session) do
          expect(described_class.session_id_for_worker).to eq(rack_session.private_id)
        end
      end
    end

    context 'when session behaves like Hash' do
      let(:session) { { set_session_id: 'abc' }.with_indifferent_access }

      it 'returns session id in Hash' do
        described_class.with_session(session) do
          expect(described_class.session_id_for_worker).to eq('abc')
        end
      end
    end

    context 'when sessionless' do
      let(:session) { nil }

      it 'returns nil' do
        described_class.with_session(session) do
          expect(described_class.session_id_for_worker).to be_nil
        end
      end
    end

    context 'when session options is a hash' do
      let(:session) do
        ActionDispatch::Request::Session.allocate.tap do |session|
          allow(session).to receive(:options).and_return({ skip: true })
        end
      end

      it 'returns nil' do
        described_class.with_session(session) do
          expect(described_class.session_id_for_worker).to be_nil
        end
      end
    end

    context 'when unknown type' do
      let(:session) { Object.new }

      it 'raises error' do
        described_class.with_session(session) do
          expect { described_class.session_id_for_worker }.to raise_error("Unsupported session class: Object")
        end
      end
    end

    context 'when an exception is raised' do
      let(:session) { { set_session_id: 'abc' }.with_indifferent_access }
      let(:exception) { StandardError.new('Something went wrong') }

      before do
        allow(session).to receive(:is_a?).and_raise(exception)
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'tracks the exception and returns nil' do
        described_class.with_session(session) do
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(exception)
          expect(described_class.session_id_for_worker).to be_nil
        end
      end
    end
  end
end
