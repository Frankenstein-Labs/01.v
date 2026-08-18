# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::QuickActions::AmazonQActions, feature_category: :duo_chat do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:issue) { create(:issue, project: project) }

  before_all do
    project.add_developer(user)
  end

  before do
    allow(Ai::AmazonQ).to receive(:enabled?).and_return(true)
  end

  describe '/q test deprecation' do
    context 'on merge request' do
      it 'shows deprecation message for test command' do
        _, updates, message = service.execute('/q test', merge_request)

        expect(updates).to be_empty
        expect(message).to include('is now supported by using /q dev')
        expect(message).to include('add an inline comment and enter /q dev')
      end
    end

    context 'on issue' do
      it 'shows unsupported command message (test was never supported on issues)' do
        _, updates, message = service.execute('/q test', issue)

        expect(updates).to be_empty
        expect(message).to include('Unsupported issue command: test')
      end
    end
  end

  describe 'supported commands still work' do
    context 'on merge request' do
      %w[dev review].each do |command|
        it "processes /q #{command} successfully" do
          _, updates, message = service.execute("/q #{command}", merge_request)

          expect(updates).to have_key(:amazon_q)
          expect(updates[:amazon_q][:command]).to eq(command)
          expect(message).to include('Q got your message!')
        end
      end
    end

    context 'on issue' do
      %w[dev transform].each do |command|
        it "processes /q #{command} successfully" do
          _, updates, message = service.execute("/q #{command}", issue)

          expect(updates).to have_key(:amazon_q)
          expect(updates[:amazon_q][:command]).to eq(command)
          expect(message).to include('Q got your message!')
        end
      end
    end
  end

  describe 'unsupported commands' do
    it 'handles unsupported command on issue' do
      _, updates, message = service.execute("/q unsupported", issue)

      expect(updates).to be_empty
      expect(message).to include('Unsupported')
    end

    it 'handles unsupported command on merge request' do
      _, updates, message = service.execute("/q unsupported", merge_request)

      expect(updates).to be_empty
      expect(message).to include('Unsupported')
    end
  end

  private

  def service
    QuickActions::InterpretService.new(
      container: project,
      current_user: user
    )
  end
end
