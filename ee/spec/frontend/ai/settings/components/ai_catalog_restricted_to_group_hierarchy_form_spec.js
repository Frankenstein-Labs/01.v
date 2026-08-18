import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlFormCheckbox, GlFormGroup, GlLink } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { helpPagePath } from '~/helpers/help_page_helper';
import AiCatalogRestrictedToGroupHierarchyForm from 'ee/ai/settings/components/ai_catalog_restricted_to_group_hierarchy_form.vue';

describe('AiCatalogRestrictedToGroupHierarchyForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(AiCatalogRestrictedToGroupHierarchyForm, {
        provide: {
          aiCatalogRestrictedToGroupHierarchy: false,
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
          GlFormGroup,
          GlLink,
        },
      }),
    );
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findLearnMoreLink = () =>
    wrapper.findByTestId('ai-catalog-restricted-to-group-hierarchy-link');

  beforeEach(() => {
    createComponent();
  });

  it('renders the section title', () => {
    expect(findFormGroup().attributes('label')).toBe('AI Catalog');
  });

  it('renders the checkbox label', () => {
    expect(findCheckbox().find('span').text()).toBe('Restrict the AI Catalog to this group');
  });

  it('renders the help text', () => {
    expect(findCheckbox().text()).toContain(
      'In the AI Catalog, show only agents and flows that belong to projects in this group hierarchy or foundational agents and flows. Agents and flows from outside this group hierarchy are hidden and cannot be turned on or used.',
    );
  });

  it('renders a Learn more link to the AI Catalog docs', () => {
    const link = findLearnMoreLink();

    expect(link.text()).toBe('What is the AI Catalog');
    expect(link.attributes('href')).toBe(helpPagePath('user/duo_agent_platform/ai_catalog'));
    expect(link.attributes('target')).toBe('_blank');
  });

  it.each`
    aiCatalogRestrictedToGroupHierarchy | description
    ${true}                             | ${'checked'}
    ${false}                            | ${'unchecked'}
  `(
    'renders the checkbox as $description when aiCatalogRestrictedToGroupHierarchy is $aiCatalogRestrictedToGroupHierarchy',
    ({ aiCatalogRestrictedToGroupHierarchy }) => {
      createComponent({ injectedProps: { aiCatalogRestrictedToGroupHierarchy } });

      expect(findCheckbox().props('checked')).toBe(aiCatalogRestrictedToGroupHierarchy);
    },
  );

  it('disables the checkbox when disabledCheckbox prop is true', () => {
    createComponent({ props: { disabledCheckbox: true } });

    expect(findCheckbox().props('disabled')).toBe(true);
  });

  it('does not disable the checkbox when disabledCheckbox prop is false', () => {
    createComponent({ props: { disabledCheckbox: false } });

    expect(findCheckbox().props('disabled')).toBe(false);
  });

  it('emits change event with the new value when the checkbox is toggled', async () => {
    createComponent({ injectedProps: { aiCatalogRestrictedToGroupHierarchy: false } });

    findCheckbox().vm.$emit('input', true);
    await nextTick();
    findCheckbox().vm.$emit('change', true);

    expect(wrapper.emitted('change')).toEqual([[true]]);
  });
});
