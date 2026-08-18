import { GlFilteredSearchSuggestion, GlFilteredSearchToken, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { OPERATOR_IS, OPERATOR_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeToken from 'ee/security_configuration/security_attributes/components/shared/attribute_token.vue';
import { stubComponent } from 'helpers/stub_component';
import { getAttributeCategoryTokens } from 'ee/security_configuration/security_attributes/components/shared/attribute_utils';
import { mockSecurityAttributeCategories } from '../mock_data';

const mockConfig = getAttributeCategoryTokens(mockSecurityAttributeCategories)[0];
const expectedAttributeOptions = mockConfig.attributeOptions;

describe('Security attribute token', () => {
  let wrapper;

  const findSearchSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);
  const findSearchSuggestionAt = (i) => findSearchSuggestions().at(i);
  const findSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);

  const createComponent = ({
    value = { operator: OPERATOR_IS },
    active = true,
    config = {},
  } = {}) => {
    wrapper = shallowMountExtended(AttributeToken, {
      propsData: {
        config: {
          ...mockConfig,
          ...config,
        },
        value,
        active,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `
          <div>
            <slot name="view-token"></slot>
            <slot name="suggestions"></slot>
          </div>
        `,
        }),
      },
    });
  };

  describe('attribute options', () => {
    beforeEach(() => createComponent());

    it('renders a search suggestion for each attribute option', () => {
      expect(findSearchSuggestions()).toHaveLength(expectedAttributeOptions.length);
    });

    it('passes the attribute name and value to the search suggestion', () => {
      expect(findSearchSuggestion().text()).toBe('Business Administrative');
      expect(findSearchSuggestion().props('value')).toBe(10);
    });
  });

  describe('search filtering', () => {
    it('filters suggestions by typed text (case-insensitive substring)', () => {
      createComponent({ value: { operator: OPERATOR_IS, data: 'critical' } });

      const suggestionText = findSearchSuggestions().wrappers.map((w) => w.text());
      expect(suggestionText).toEqual(['Business Critical', 'Mission Critical']);
    });

    it('shows all options when the input is empty', () => {
      createComponent({ value: { operator: OPERATOR_IS, data: '' } });

      expect(findSearchSuggestions()).toHaveLength(expectedAttributeOptions.length);
    });

    it('does not treat the selected array as a search term', () => {
      createComponent({ value: { operator: OPERATOR_OR, data: [10, 11] } });

      expect(findSearchSuggestions()).toHaveLength(expectedAttributeOptions.length);
    });

    it('ignores typed text when the token is inactive', () => {
      createComponent({ value: { operator: OPERATOR_IS, data: 'critical' }, active: false });

      expect(findSearchSuggestions()).toHaveLength(expectedAttributeOptions.length);
    });

    it('shows no options when the search term matches nothing', () => {
      createComponent({ value: { operator: OPERATOR_IS, data: 'zzz-no-match' } });

      expect(findSearchSuggestions()).toHaveLength(0);
    });
  });

  describe('attribute selection', () => {
    it('initializes selectedValues from value.data', () => {
      createComponent({ value: { operator: OPERATOR_OR, data: [10, 11] } });

      expect(findSearchToken().props('multiSelectValues')).toStrictEqual([10, 11]);
    });

    it('selects a single attribute', async () => {
      createComponent();

      findSearchToken().vm.$emit('select', 10);
      await nextTick();

      expect(findSearchToken().props('multiSelectValues')).toStrictEqual([10]);
      expect(wrapper.vm.toggleText).toBe('Business Administrative');
    });

    it('selects many attributes', async () => {
      createComponent({ value: { operator: OPERATOR_OR }, config: { multiSelect: true } });

      findSearchToken().vm.$emit('select', 10);
      findSearchToken().vm.$emit('select', 11);
      findSearchToken().vm.$emit('select', 8);
      findSearchToken().vm.$emit('select', 7);
      await nextTick();

      const selectedOption = findSearchSuggestionAt(0); // 10
      const unselectedOption = findSearchSuggestionAt(2); // 9

      expect(selectedOption.text()).toBe('Business Administrative');
      expect(selectedOption.findComponent(GlIcon).classes()).not.toContain('gl-invisible');
      expect(unselectedOption.text()).toBe('Business Operational');
      expect(unselectedOption.findComponent(GlIcon).classes()).toContain('gl-invisible');
      expect(findSearchToken().props('multiSelectValues')).toStrictEqual([10, 11, 8, 7]);
      expect(wrapper.vm.toggleText).toBe('Business Administrative, Business Critical +2 more');
    });
  });

  describe('transformFilters', () => {
    const { transformFilters } = AttributeToken;

    it('maps "||" operator to IS_ONE_OF and converts IDs to GraphQL IDs', () => {
      const result = transformFilters([10, 11], { filters: {}, operator: '||' });

      expect(result).toStrictEqual({
        securityAttributesFilters: [
          {
            operator: 'IS_ONE_OF',
            attributes: [
              'gid://gitlab/Security::Attribute/10',
              'gid://gitlab/Security::Attribute/11',
            ],
          },
        ],
      });
    });

    it('maps "!=" operator to IS_NOT_ONE_OF', () => {
      const result = transformFilters([8], { filters: {}, operator: '!=' });

      expect(result).toStrictEqual({
        securityAttributesFilters: [
          {
            operator: 'IS_NOT_ONE_OF',
            attributes: ['gid://gitlab/Security::Attribute/8'],
          },
        ],
      });
    });

    it('appends to existing securityAttributesFilters', () => {
      const existing = [
        { operator: 'IS_ONE_OF', attributes: ['gid://gitlab/Security::Attribute/1'] },
      ];
      const result = transformFilters([9], {
        filters: { securityAttributesFilters: existing },
        operator: '||',
      });

      expect(result.securityAttributesFilters).toHaveLength(2);
      expect(result.securityAttributesFilters[0]).toBe(existing[0]);
      expect(result.securityAttributesFilters[1]).toStrictEqual({
        operator: 'IS_ONE_OF',
        attributes: ['gid://gitlab/Security::Attribute/9'],
      });
    });
  });
});
