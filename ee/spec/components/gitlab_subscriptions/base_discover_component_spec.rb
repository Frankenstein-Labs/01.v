# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::BaseDiscoverComponent, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }

  subject(:component) { render_inline(test_discover_class.new(namespace: namespace)) }

  context 'for ensuring methods are created by inheriting classes' do
    let(:test_discover_class) do
      klass = Class.new(described_class)

      klass.class_exec(no_method_name) do |method_name|
        define_method(:trial_type) { 'type' } unless method_name == :trial_type
        define_method(:trial_active?) { true } unless method_name == :trial_active?
        define_method(:text_page_title) { 'title' } unless method_name == :text_page_title
        define_method(:hero_logo) { 'logo' } unless method_name == :hero_logo
        define_method(:hero_logo_dark) { 'logo' } unless method_name == :hero_logo_dark
        define_method(:hero_header_text) { 'hero_text' } unless method_name == :hero_header_text
        define_method(:buy_now_link) { 'some/link' } unless method_name == :buy_now_link
        define_method(:cta_button_text) { 'Buy now' } unless method_name == :cta_button_text
        define_method(:hero_video) { 'some/video' } unless method_name == :hero_video
        define_method(:why_section_header_text) { 'header_text' } unless method_name == :why_section_header_text

        unless method_name == :core_feature_one_header_text
          define_method(:core_feature_one_header_text) do
            'header_text'
          end
        end

        define_method(:hero_thumbnail) { 'duo_pro/video-thumbnail.png' } unless method_name == :hero_thumbnail
        define_method(:discover_card_collection) { [] } unless method_name == :discover_card_collection
        define_method(:core_section_one_card_collection) { [] } unless method_name == :core_section_one_card_collection
        define_method(:glm_content) { 'glm_content' } unless method_name == :glm_content
      end

      klass
    end

    before do
      stub_const('TestDiscoverClass', test_discover_class)
    end

    context 'for methods that must be implemented by subclasses' do
      where(:no_method_name) do
        [
          :trial_type,
          :trial_active?,
          :text_page_title,
          :hero_logo,
          :hero_logo_dark,
          :hero_header_text,
          :buy_now_link,
          :cta_button_text,
          :hero_video,
          :why_section_header_text,
          :core_feature_one_header_text,
          :hero_thumbnail,
          :discover_card_collection,
          :core_section_one_card_collection,
          :glm_content
        ]
      end

      with_them do
        it 'raises an error for the unimplemented method' do
          expect { component }.to raise_error(Gitlab::AbstractMethodError)
        end
      end
    end

    context 'with hero_tagline_text' do
      let(:no_method_name) { nil }

      it 'does not render hero tagline section by default' do
        expect(component).not_to have_css('[data-testid="hero-tagline-text"]')
      end

      it 'renders hero tagline text when implementation returns a value' do
        allow_next_instance_of(test_discover_class) do |instance|
          allow(instance).to receive(:hero_tagline_text).and_return(
            'New customers can get access to GitLab Premium with Duo'
          )
        end

        expect(component).to have_css('[data-testid="hero-tagline-text"]',
          text: 'New customers can get access to GitLab Premium with Duo')
      end
    end

    context 'when core_section_two_card_collection is not empty' do
      let(:no_method_name) { nil }

      it 'renders another row of feature cards' do
        allow_next_instance_of(test_discover_class) do |instance|
          allow(instance).to receive(:core_section_two_card_collection).and_return(
            [
              {
                header: 'Feature A',
                body: 'This is feature A'
              },
              {
                header: 'Feature B',
                body: 'This is feature B'
              }
            ]
          )
        end

        expect(component).to have_css('[data-testid="core-2-entry"]', count: 2)
      end
    end

    context 'with buy_now_url' do
      let(:no_method_name) { nil }

      it 'renders the bare buy_now_link when buy_now_ref_source is nil' do
        expect(component).to have_link('Buy now', href: 'some/link')
      end

      it 'buy_now_url returns nil when buy_now_link is blank' do
        allow_next_instance_of(test_discover_class) do |instance|
          allow(instance).to receive(:buy_now_link).and_return(nil)
          expect(instance.send(:buy_now_url)).to be_nil
        end
        component
      end

      context 'when buy_now_ref_source is present' do
        before do
          allow_next_instance_of(test_discover_class) do |instance|
            allow(instance).to receive(:buy_now_ref_source).and_return('some_source')
          end
        end

        it 'appends ref_source query param to the link' do
          expect(component).to have_link('Buy now', href: /ref_source=some_source/)
        end
      end

      context 'when buy_now_link is blank' do
        before do
          allow_next_instance_of(test_discover_class) do |instance|
            allow(instance).to receive(:buy_now_link).and_return(nil)
          end
        end

        it 'does not render a Buy now link' do
          expect(component).not_to have_link('Buy now')
        end
      end
    end
  end
end
