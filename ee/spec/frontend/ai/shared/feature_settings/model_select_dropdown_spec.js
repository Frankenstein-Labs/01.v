import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { mockListItems as mockSelfHostedModelsItems } from '../../instance_model_selection/self_hosted_models/mock_data';
import { mockListItems as mockModelSelectionItems } from '../../model_selection/mock_data';
import { mockGroupedModelItems } from './mock_data';

describe('ModelSelectDropdown', () => {
  let wrapper;

  const placeholderDropdownText = 'Select model';
  const selectedOption = mockSelfHostedModelsItems[0];

  const createComponent = ({ props = {}, features = {} } = {}) => {
    wrapper = extendedWrapper(
      mount(ModelSelectDropdown, {
        provide: {
          glFeatures: {
            ...features,
          },
        },
        propsData: {
          items: mockSelfHostedModelsItems,
          placeholderDropdownText,
          selectedOption,
          ...props,
        },
      }),
    );
  };

  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findGLCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownToggleText = () => wrapper.findByTestId('dropdown-toggle-text');
  const findModelNames = () => wrapper.findAllByTestId('model-name');
  const findModelProviders = () => wrapper.findAllByTestId('model-provider');
  const findModelDescriptions = () => wrapper.findAllByTestId('model-description');
  const findModelCostIndicators = () => wrapper.findAllByTestId('model-cost-indicator');
  const findBetaModelSelectedBadge = () => wrapper.findByTestId('beta-model-selected-badge');
  const findBetaModelDropdownBadges = () => wrapper.findAllByTestId('beta-model-dropdown-badge');
  const findToggleButton = () => wrapper.findComponentByTestId('toggle-button');
  const findToggleSubtext = () => wrapper.findByTestId('dropdown-toggle-subtext');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelectDropdown().exists()).toBe(true);
  });

  describe('dropdown toggle text', () => {
    it('renders the placeholder text when no selected option is provided', () => {
      createComponent({
        props: { selectedOption: null },
      });

      expect(findDropdownToggleText().text()).toBe(placeholderDropdownText);
    });

    it('displays the text based on selected option', () => {
      createComponent();

      expect(findDropdownToggleText().text()).toBe(selectedOption.text);
    });

    describe('subtext', () => {
      it('does not render the subtext element when the selected option has no subtext', () => {
        createComponent();

        expect(findToggleSubtext().exists()).toBe(false);
      });

      it('renders the subtext under the model name when the selected option has a subtext', () => {
        createComponent({
          props: { selectedOption: { ...selectedOption, subtext: 'GitLab managed model' } },
        });

        expect(findToggleSubtext().text()).toBe('GitLab managed model');
      });
    });
  });

  describe('when isLoading is true', () => {
    it('renders the loading state', () => {
      createComponent({ props: { isLoading: true } });

      expect(findGLCollapsibleListbox().props('loading')).toBe(true);
    });
  });

  describe('when disabled is true', () => {
    it('disables the dropdown toggle', () => {
      createComponent({ props: { disabled: true } });
      expect(findToggleButton().props('disabled')).toBe(true);
    });
  });

  describe('items', () => {
    it('renders list items', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('items')).toBe(mockSelfHostedModelsItems);
    });

    describe('Self-hosted model items', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders model names and styles them correctly', () => {
        mockSelfHostedModelsItems.forEach((item, index) => {
          const modelName = findModelNames().at(index);

          expect(modelName.text()).toEqual(item.text);
          expect(modelName.classes()).not.toContain('gl-font-bold');
        });
      });

      describe('beta models', () => {
        it('displays the beta badge with dropdown options', () => {
          expect(findBetaModelDropdownBadges()).toHaveLength(3);
        });

        it('displays the beta badge when beta option is selected', () => {
          const betaModel = mockSelfHostedModelsItems[1];

          createComponent({ props: { selectedOption: betaModel } });

          expect(findBetaModelSelectedBadge().exists()).toBe(true);
        });
      });
    });

    describe('GitLab model items', () => {
      beforeEach(() => {
        createComponent({ props: { items: mockModelSelectionItems } });
      });

      it('renders model names and styles them correctly', () => {
        mockModelSelectionItems.forEach((item, index) => {
          const modelName = findModelNames().at(index);

          expect(modelName.text()).toEqual(item.text);
          expect(modelName.classes()).toContain('gl-font-bold');
        });
      });

      it('renders model providers', () => {
        mockModelSelectionItems.forEach((item, index) => {
          expect(findModelProviders().at(index).text()).toEqual(item.provider);
        });
      });

      it('renders model descriptions', () => {
        mockModelSelectionItems.forEach((item, index) => {
          expect(findModelDescriptions().at(index).text()).toEqual(item.description);
        });
      });

      describe('cost indicators', () => {
        it('renders model cost indicators', () => {
          mockModelSelectionItems.forEach((item, index) => {
            expect(findModelCostIndicators().at(index).text()).toEqual(item.costIndicator);
          });
        });
      });
    });

    it('sets a default selected value based on the selected option', () => {
      createComponent({
        props: {
          selectedOption,
        },
      });

      const dropdown = findGLCollapsibleListbox();

      // selected based on selected option prop
      expect(dropdown.props('selected')).toBe(selectedOption.value);
    });

    it('emits select event when an item is selected', async () => {
      createComponent();

      findGLCollapsibleListbox().vm.$emit('select', selectedOption.value);
      await nextTick();

      expect(wrapper.emitted('select')).toStrictEqual([[selectedOption.value]]);
    });
  });

  describe('search/filter', () => {
    it('renders the listbox as searchable', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('searchable')).toBe(true);
    });

    describe('items with a single type of model', () => {
      beforeEach(() => {
        createComponent();
      });

      it('filters items based on search term', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'claude');
        await nextTick();

        const filteredItems = findGLCollapsibleListbox().props('items');
        expect(filteredItems.every((item) => item.text.toLowerCase().includes('claude'))).toBe(
          true,
        );
      });

      it('shows all items when search term is empty', () => {
        findGLCollapsibleListbox().vm.$emit('search', 'claude');
        findGLCollapsibleListbox().vm.$emit('search', '');

        expect(findGLCollapsibleListbox().props('items')).toStrictEqual(mockSelfHostedModelsItems);
      });

      it('shows no results text when no items match the search term', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'zzznomatch');
        await nextTick();

        expect(findGLCollapsibleListbox().props('items')).toHaveLength(0);
        expect(findGLCollapsibleListbox().props('noResultsText')).toBe('No results found');
      });

      it('search is case-insensitive', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'CLAUDE');
        await nextTick();

        const filteredItems = findGLCollapsibleListbox().props('items');
        expect(filteredItems.every((item) => item.text.toLowerCase().includes('claude'))).toBe(
          true,
        );
      });
    });

    describe('items with both self-hosted and GitLab models', () => {
      beforeEach(() => {
        createComponent({ props: { items: mockGroupedModelItems } });
      });

      it('filters options within groups based on search term', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'claude');
        await nextTick();

        const filteredItems = findGLCollapsibleListbox().props('items');
        expect(filteredItems).toHaveLength(2);
        expect(filteredItems[0].options).toEqual([{ value: 'model-2', text: 'Claude Instant' }]);
        expect(filteredItems[1].options).toEqual([{ value: 'model-3', text: 'Claude Sonnet 3.5' }]);
      });

      it('removes groups with no matching options', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'gpt');
        await nextTick();

        const filteredItems = findGLCollapsibleListbox().props('items');
        expect(filteredItems).toHaveLength(1);
        expect(filteredItems[0].text).toBe('GitLab managed models');
        expect(filteredItems[0].options).toEqual([{ value: 'model-4', text: 'GPT-4o' }]);
      });

      it('shows all grouped items when search term is empty', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'claude');
        await nextTick();
        findGLCollapsibleListbox().vm.$emit('search', '');
        await nextTick();

        expect(findGLCollapsibleListbox().props('items')).toStrictEqual(mockGroupedModelItems);
      });

      it('shows no results when no grouped options match', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'zzznomatch');
        await nextTick();

        expect(findGLCollapsibleListbox().props('items')).toHaveLength(0);
      });

      it('search is case-insensitive for grouped items', async () => {
        findGLCollapsibleListbox().vm.$emit('search', 'MISTRAL');
        await nextTick();

        const filteredItems = findGLCollapsibleListbox().props('items');
        expect(filteredItems).toHaveLength(1);
        expect(filteredItems[0].text).toBe('Self-hosted models');
        expect(filteredItems[0].options).toEqual([{ value: 'model-1', text: 'Mistral 7B' }]);
      });
    });
  });
});
