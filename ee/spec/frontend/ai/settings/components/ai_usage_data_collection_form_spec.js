import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlLink, GlFormGroup } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { AI_USAGE_DATA_COLLECTION_DOCS_URL } from 'ee/ai/settings/constants';
import AiUsageDataCollectionForm from 'ee/ai/settings/components/ai_usage_data_collection_form.vue';

describe('AiUsageDataCollectionForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(AiUsageDataCollectionForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
          GlLink,
          GlFormGroup,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { aiUsageDataCollectionEnabled: true } });
  });

  const findTitle = () => wrapper.findComponent(GlFormGroup);
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findDataUsageLink = () => wrapper.findByTestId('ai-usage-data-collection-link');

  it('has the correct title', () => {
    expect(findTitle().attributes('label')).toBe('Data collection');
  });

  it('has the correct label', () => {
    expect(findCheckbox().find('span').text()).toBe('Collect usage data');
  });

  it('has the correct help text', () => {
    expect(findCheckbox().text()).toContain(
      'Allow GitLab to collect prompts, AI responses, and metadata from user interactions with GitLab Duo. This data helps improve service quality and is not used to train models.',
    );
  });

  it('renders a Learn more link to the docs', () => {
    const link = findDataUsageLink();

    expect(link.text()).toBe('Which data is collected');
    expect(link.attributes('href')).toBe(AI_USAGE_DATA_COLLECTION_DOCS_URL);
    expect(link.attributes('target')).toBe('_blank');
  });

  it.each`
    aiUsageDataCollectionEnabled | description
    ${true}                      | ${'checked'}
    ${false}                     | ${'unchecked'}
  `(
    'renders the checkbox as $description when aiUsageDataCollectionEnabled is set to $aiUsageDataCollectionEnabled',
    ({ aiUsageDataCollectionEnabled }) => {
      createComponent({ injectedProps: { aiUsageDataCollectionEnabled } });

      expect(findCheckbox().props('checked')).toBe(aiUsageDataCollectionEnabled);
    },
  );

  it('disables the checkbox when disabledCheckbox prop is true', () => {
    createComponent({
      injectedProps: { aiUsageDataCollectionEnabled: true },
      props: { disabledCheckbox: true },
    });

    expect(findCheckbox().props('disabled')).toBe(true);
  });

  it('does not disable the checkbox when disabledCheckbox prop is false', () => {
    createComponent({
      injectedProps: { aiUsageDataCollectionEnabled: true },
      props: { disabledCheckbox: false },
    });

    expect(findCheckbox().props('disabled')).toBe(false);
  });
});
