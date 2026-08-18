import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { print } from 'graphql/language/printer';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AttributeSelector from 'ee/security_orchestration/components/policy_editor/scope/attribute_selector.vue';
import AttributeValueSelector from 'ee/security_orchestration/components/policy_editor/scope/attribute_value_selector.vue';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';

Vue.use(VueApollo);

const mockCategories = [
  {
    id: 'gid://gitlab/Security::Category/1',
    name: 'Business Impact',
    description: 'Business impact category',
    multipleSelection: false,
    editableState: 'EDITABLE',
    templateType: 'BUSINESS_IMPACT',
    securityAttributes: [
      {
        id: 'gid://gitlab/Security::Attribute/1',
        name: 'Mission Critical',
        description: 'Mission critical',
        color: '#ff0000',
      },
      {
        id: 'gid://gitlab/Security::Attribute/2',
        name: 'Business Critical',
        description: 'Business critical',
        color: '#ff8800',
      },
    ],
  },
  {
    id: 'gid://gitlab/Security::Category/2',
    name: 'Exposure level',
    description: 'Exposure level category',
    multipleSelection: false,
    editableState: 'EDITABLE',
    templateType: 'EXPOSURE',
    securityAttributes: [
      {
        id: 'gid://gitlab/Security::Attribute/3',
        name: 'Internet',
        description: 'Internet exposed',
        color: '#0000ff',
      },
    ],
  },
  {
    id: 'gid://gitlab/Security::Category/5',
    name: 'New Category',
    description: 'Custom category',
    multipleSelection: true,
    editableState: 'EDITABLE',
    templateType: null,
    securityAttributes: [
      {
        id: 'gid://gitlab/Security::Attribute/10',
        name: 'Custom Value',
        description: 'A custom attribute',
        color: '#00ff00',
      },
    ],
  },
];

const mockResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      securityCategories: mockCategories,
    },
  },
};

describe('AttributeSelector', () => {
  let wrapper;
  let requestHandler;

  const createComponent = ({ propsData = {}, handler } = {}) => {
    requestHandler = handler || jest.fn().mockResolvedValue(mockResponse);

    wrapper = shallowMountExtended(AttributeSelector, {
      apolloProvider: createMockApollo([[getSecurityCategoriesAndAttributes, requestHandler]]),
      propsData: {
        ...propsData,
      },
      provide: {
        rootNamespacePath: 'gitlab-org-root',
      },
      stubs: {
        GlCollapsibleListbox,
        GlSprintf,
      },
    });
  };

  const findCategoryDropdown = () => wrapper.findComponentByTestId('category-dropdown');
  const findIncludingSelector = () => wrapper.findComponentByTestId('including-selector');
  const findExcludingSelector = () => wrapper.findComponentByTestId('excluding-selector');
  const findExceptionDropdown = () => wrapper.findComponentByTestId('exception-dropdown');
  const findAllAttributeSelectors = () => wrapper.findAllComponents(AttributeValueSelector);

  describe('GraphQL query', () => {
    it('fetches security categories using rootNamespacePath', () => {
      createComponent();

      expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'gitlab-org-root' });
    });

    it('emits error event when query fails', async () => {
      createComponent({ handler: jest.fn().mockRejectedValue(new Error('fail')) });

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('category dropdown', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders only the four supported built-in categories from the query response', () => {
      const items = findCategoryDropdown().props('items');

      expect(items).toEqual([
        { value: 'business_impact', text: 'Business Impact', disabled: false },
        { value: 'exposure', text: 'Exposure level', disabled: false },
      ]);
    });

    it('marks categories listed in disabledCategoryKeys as disabled without removing them', async () => {
      createComponent({ propsData: { disabledCategoryKeys: ['exposure'] } });
      await waitForPromises();

      expect(findCategoryDropdown().props('items')).toEqual([
        { value: 'business_impact', text: 'Business Impact', disabled: false },
        { value: 'exposure', text: 'Exposure level', disabled: true },
      ]);
    });

    it('disables dropdown when disabled prop is true', async () => {
      createComponent({ propsData: { disabled: true } });
      await waitForPromises();

      expect(findCategoryDropdown().props('disabled')).toBe(true);
    });

    it('renders only the including selector before category selection', () => {
      expect(findIncludingSelector().exists()).toBe(true);
      expect(findExcludingSelector().exists()).toBe(false);
      expect(findIncludingSelector().props('disabled')).toBe(true);
    });
  });

  describe('including selector', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes attribute items for the selected category', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');

      expect(findIncludingSelector().props('items')).toEqual([
        { value: 'gid://gitlab/Security::Attribute/1', text: 'Mission Critical', color: '#ff0000' },
        {
          value: 'gid://gitlab/Security::Attribute/2',
          text: 'Business Critical',
          color: '#ff8800',
        },
      ]);
    });

    it('clears its selection when switching categories', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findIncludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/1']);

      await findCategoryDropdown().vm.$emit('select', 'exposure');

      expect(findIncludingSelector().props('selected')).toEqual([]);
    });

    it('emits @changed with the including ids when values are selected', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findIncludingSelector().vm.$emit('select', [
        'gid://gitlab/Security::Attribute/1',
        'gid://gitlab/Security::Attribute/2',
      ]);

      expect(wrapper.emitted('changed').at(-1)).toEqual([
        { business_impact: { including: [{ id: 1 }, { id: 2 }] } },
      ]);
    });

    it('handles @select-all and @reset by forwarding to the including list', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');

      await findIncludingSelector().vm.$emit('select-all', [
        'gid://gitlab/Security::Attribute/1',
        'gid://gitlab/Security::Attribute/2',
      ]);
      expect(wrapper.emitted('changed').at(-1)).toEqual([
        { business_impact: { including: [{ id: 1 }, { id: 2 }] } },
      ]);

      await findIncludingSelector().vm.$emit('reset');
      expect(wrapper.emitted('changed').at(-1)).toEqual([{ business_impact: { including: [] } }]);
    });

    it('marks the category as empty when no attributes exist', async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue({
          data: {
            group: {
              id: 'gid://gitlab/Group/1',
              securityCategories: [
                {
                  id: 'gid://gitlab/Security::Category/99',
                  name: 'Application',
                  description: '',
                  multipleSelection: false,
                  templateType: 'APPLICATION',
                  securityAttributes: [],
                },
              ],
            },
          },
        }),
      });
      await waitForPromises();

      await findCategoryDropdown().vm.$emit('select', 'application');

      expect(findIncludingSelector().props('isCategoryEmpty')).toBe(true);
    });
  });

  describe('exception dropdown', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('offers the two exception options with no_exceptions (including) as the default', () => {
      expect(findExceptionDropdown().props('items')).toEqual([
        { value: 'including', text: 'no exceptions' },
        { value: 'excluding', text: 'exceptions' },
      ]);
      expect(findExceptionDropdown().props('selected')).toBe('including');
    });

    it('reveals the excluding selector only when exceptions is picked', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      expect(findExcludingSelector().exists()).toBe(false);

      await findExceptionDropdown().vm.$emit('select', 'excluding');

      expect(findExcludingSelector().exists()).toBe(true);
    });

    it('emits a payload with both including and excluding in exceptions mode', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findIncludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/1']);
      await findExceptionDropdown().vm.$emit('select', 'excluding');
      await findExcludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/2']);

      expect(wrapper.emitted('changed').at(-1)).toEqual([
        { business_impact: { including: [{ id: 1 }], excluding: [{ id: 2 }] } },
      ]);
    });

    it('clears excluding selection and hides the selector when toggled back to no-exceptions', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findExceptionDropdown().vm.$emit('select', 'excluding');
      await findExcludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/2']);

      await findExceptionDropdown().vm.$emit('select', 'including');

      expect(findExcludingSelector().exists()).toBe(false);
      expect(wrapper.emitted('changed').at(-1)).toEqual([{ business_impact: { including: [] } }]);
    });

    it('hydrates both selectors from an existing scope with both lists', async () => {
      createComponent({
        propsData: {
          policyScope: {
            business_impact: {
              including: [{ id: 1 }],
              excluding: [{ id: 2 }],
            },
          },
        },
      });

      await waitForPromises();

      expect(findExceptionDropdown().props('selected')).toBe('excluding');
      expect(findIncludingSelector().props('selected')).toEqual([
        'gid://gitlab/Security::Attribute/1',
      ]);
      expect(findExcludingSelector().exists()).toBe(true);
      expect(findExcludingSelector().props('selected')).toEqual([
        'gid://gitlab/Security::Attribute/2',
      ]);
    });
  });

  describe('emitting changes', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('emits @changed with empty including on first category selection', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');

      expect(wrapper.emitted('changed')).toEqual([[{ business_impact: { including: [] } }]]);
    });

    it('emits only the newly selected category key when switching categories', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findCategoryDropdown().vm.$emit('select', 'exposure');

      expect(wrapper.emitted('changed')).toEqual([
        [{ business_impact: { including: [] } }],
        [{ exposure: { including: [] } }],
      ]);
    });

    it('resets the exception type to including when switching categories', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findExceptionDropdown().vm.$emit('select', 'excluding');
      await findExcludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/1']);

      await findCategoryDropdown().vm.$emit('select', 'exposure');

      expect(wrapper.emitted('changed').at(-1)).toEqual([{ exposure: { including: [] } }]);
      expect(findExceptionDropdown().props('selected')).toBe('including');
      expect(findExcludingSelector().exists()).toBe(false);
    });

    it('converts GraphQL IDs to numeric IDs in payload', async () => {
      await findCategoryDropdown().vm.$emit('select', 'business_impact');
      await findIncludingSelector().vm.$emit('select', ['gid://gitlab/Security::Attribute/42']);

      const lastChanged = wrapper.emitted('changed').at(-1);

      expect(lastChanged).toEqual([{ business_impact: { including: [{ id: 42 }] } }]);
    });
  });

  describe('existing policy scope', () => {
    it('initializes from existing policyScope', async () => {
      createComponent({
        propsData: {
          policyScope: {
            business_impact: {
              including: [{ id: 1 }],
            },
          },
        },
      });

      await waitForPromises();

      expect(findCategoryDropdown().props('selected')).toBe('business_impact');
      expect(findIncludingSelector().props('selected')).toEqual([
        'gid://gitlab/Security::Attribute/1',
      ]);
    });

    it('ignores reserved scope keys when deriving the selected category', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: { including: [{ id: 5 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      await waitForPromises();

      expect(findCategoryDropdown().props('selected')).toBe('exposure');
      expect(findIncludingSelector().props('selected')).toEqual([
        'gid://gitlab/Security::Attribute/3',
      ]);
    });

    it('treats a non-array including value as an empty selection', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: null } },
        },
      });

      await waitForPromises();

      expect(findIncludingSelector().props('selected')).toEqual([]);
    });
  });

  describe('disabled state', () => {
    it('propagates disabled to the attribute selector(s)', async () => {
      createComponent({
        propsData: {
          disabled: true,
          policyScope: {
            business_impact: {
              including: [{ id: 1 }],
              excluding: [{ id: 2 }],
            },
          },
        },
      });

      await waitForPromises();

      expect(findCategoryDropdown().props('disabled')).toBe(true);
      findAllAttributeSelectors().wrappers.forEach((selector) => {
        expect(selector.props('disabled')).toBe(true);
      });
    });
  });

  // Contract test — the query is imported from security_configuration/ and shared
  // with other consumers. If someone removes a field below from the shared query,
  // AttributeSelector silently breaks. This spec catches that at lint time.
  describe('getSecurityCategoriesAndAttributes query contract', () => {
    const queryText = print(getSecurityCategoriesAndAttributes);

    it.each([
      ['securityCategories (root selection)', 'securityCategories'],
      ['category.id', /securityCategories\s*{[^}]*\bid\b/],
      ['category.name', /securityCategories\s*{[^}]*\bname\b/],
      ['category.templateType', /securityCategories\s*{[^}]*\btemplateType\b/],
      ['securityAttributes (nested selection)', 'securityAttributes'],
      ['attribute.id', /securityAttributes\s*{[^}]*\bid\b/],
      ['attribute.name', /securityAttributes\s*{[^}]*\bname\b/],
      ['attribute.color', /securityAttributes\s*{[^}]*\bcolor\b/],
    ])('selects %s (AttributeSelector depends on this)', (_label, matcher) => {
      expect(queryText).toMatch(matcher);
    });
  });
});
