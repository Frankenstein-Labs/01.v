import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CiTemplateDropdown from 'ee/pages/admin/application_settings/ci_cd/ci_template_dropdown.vue';
import { MOCK_CI_YMLS, initialSelectedName } from './mock_data';

describe('CiTemplateDropdown', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const templates = MOCK_CI_YMLS.Security;

  const createComponent = (provide) => {
    wrapper = shallowMount(CiTemplateDropdown, {
      provide: { gitlabCiYmls: MOCK_CI_YMLS, ...provide },
    });
  };

  describe('renders', () => {
    beforeEach(() => {
      createComponent();
    });

    it('dropdown', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('renders the correct default text', () => {
      expect(findListbox().props('headerText')).toBe('Select a CI/CD template');
      expect(findListbox().props('searchPlaceholder')).toBe('No required configuration');
      expect(findListbox().props('resetButtonLabel')).toBe('Reset');
    });
  });

  describe('when initial value is not provided', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders listbox toggle button with no selected item', () => {
      expect(findListbox().props('toggleText')).toBe('No required configuration');
    });

    it('no selected item is checked', () => {
      expect(findListbox().props('selected')).toBe(null);
    });

    describe('when item is selected', () => {
      it('populates correct props', async () => {
        await findListbox().vm.$emit('select', templates[0].key);
        expect(findListbox().props('selected')).toBe(templates[0].key);
        expect(findListbox().props('toggleText')).toBe(templates[0].key);
      });
    });
  });

  describe('when initial value is provided', () => {
    beforeEach(() => {
      createComponent({ initialSelectedGitlabCiYmlName: initialSelectedName });
    });

    it('renders listbox toggle button with selected template name', () => {
      expect(findListbox().props('toggleText')).toBe(initialSelectedName);
    });

    it('selected template is checked', () => {
      expect(findListbox().props('selected')).toBe(initialSelectedName);
    });

    describe('when dropdown is reset', () => {
      it('clears selected', async () => {
        expect(findListbox().props('selected')).toBe(initialSelectedName);
        await findListbox().vm.$emit('reset');
        expect(findListbox().props('selected')).toBe(null);
      });
    });
  });

  describe('when searching with filter', () => {
    const searchTerm = 'fi';

    beforeEach(() => {
      createComponent();
      findListbox().vm.$emit('search', searchTerm);
    });

    it('filters items correctly', () => {
      const expected = [
        {
          text: 'Security',
          options: [{ value: 'fizz', text: 'fizz' }],
        },
      ];
      expect(findListbox().props('items')).toEqual(expected);
    });
  });
});
