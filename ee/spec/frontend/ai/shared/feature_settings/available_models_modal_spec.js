import { GlAlert, GlFormCheckbox, GlLink, GlModal } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import AvailableModelsModal from 'ee/ai/shared/feature_settings/available_models_modal.vue';
import { mockAgenticChatFeatureSetting } from 'ee_jest/ai/instance_model_selection/feature_settings/mock_data';

describe('AvailableModelsModal', () => {
  let wrapper;

  const mockFeatureTitle = mockAgenticChatFeatureSetting.title;
  const mockAvailableModels = mockAgenticChatFeatureSetting.allowList.models.nodes;
  const mockChosenModelForFeature = mockAgenticChatFeatureSetting.gitlabModel;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(AvailableModelsModal, {
      propsData: {
        availableModels: mockAvailableModels,
        chosenModelForFeature: mockChosenModelForFeature,
        featureTitle: mockFeatureTitle,
        visible: true,
        ...props,
      },
      stubs: {
        GlModal: stubComponent(GlModal),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findAllowListCheckbox = () => wrapper.findByTestId('allow-list-checkbox');
  const findModelCheckboxes = () => wrapper.findAllByTestId('model-checkbox');
  const findModelCheckboxByRef = (ref) => wrapper.find(`input[value="${ref}"]`);
  const findModelText = () => wrapper.findAllByTestId('model-text');
  const findSelectedModelsSummary = () => wrapper.findByTestId('selected-models-summary');
  const findGitLabManagedModelsHelpLink = () => wrapper.findComponent(GlLink);
  const findModelItems = () => wrapper.findAllByTestId('model-item').wrappers;
  const findModelNames = () => wrapper.findAllByTestId('model-name');
  const findLockedModelIndicator = () => wrapper.findByTestId('locked-model-indicator');
  const findSelectAllToolbar = () => wrapper.findByTestId('select-all-toolbar');
  const findSelectAllCheckbox = () => wrapper.findByTestId('select-all-checkbox');
  const findScrollableList = () => wrapper.findByTestId('models-list');

  beforeEach(() => {
    createComponent();
  });

  it('passes `visible` prop to GlModal', () => {
    expect(findModal().props('visible')).toBe(true);
  });

  it('emits `update:visible` and clears the error when hidden', () => {
    findModal().vm.$emit('hidden');

    expect(wrapper.emitted('update:visible')).toEqual([[false]]);
    expect(wrapper.emitted('update:error-message')).toEqual([['']]);
  });

  it('renders with the correct title', () => {
    expect(findModal().props('title')).toBe(`Available models: ${mockFeatureTitle}`);
  });

  it('renders a `Cancel` button', () => {
    expect(findModal().props('actionCancel')).toMatchObject({ text: 'Cancel' });
  });

  describe('save button', () => {
    it('renders correctly', () => {
      expect(findModal().props('actionPrimary')).toMatchObject({ text: 'Save' });
    });

    it('reflects the `loading` prop on the action', () => {
      createComponent({ props: { loading: true } });

      expect(findModal().props('actionPrimary').attributes.loading).toBe(true);
    });

    describe('when clicked', () => {
      const triggerPrimary = () => {
        const event = { preventDefault: jest.fn() };
        findModal().vm.$emit('primary', event);
        return event;
      };

      it('keeps the modal open by preventing the default close', () => {
        const event = triggerPrimary();

        expect(event.preventDefault).toHaveBeenCalled();
      });

      it('emits `save` with no model refs when allow-list is disabled', () => {
        triggerPrimary();

        expect(wrapper.emitted('save')).toEqual([[{ enabled: false, allowedModelRefs: [] }]]);
      });

      it('emits `save` with the selected model refs when allow-list is enabled', async () => {
        await findAllowListCheckbox().find('input').setChecked(true);
        await findModelCheckboxes().at(1).find('input').setChecked(false);

        triggerPrimary();

        expect(wrapper.emitted('save')).toEqual([
          [{ enabled: true, allowedModelRefs: ['claude_sonnet_4_20250514', 'claude_sonnet_4_6'] }],
        ]);
      });
    });

    describe('when allow-list is enabled', () => {
      beforeEach(() => {
        findAllowListCheckbox().find('input').setChecked(true);
      });

      describe('when more models than just the locked model are selected', () => {
        it('is enabled', () => {
          expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
        });
      });

      describe('when only the locked model is selected', () => {
        beforeEach(async () => {
          await findModelCheckboxes().at(0).find('input').setChecked(false);
          await findModelCheckboxes().at(1).find('input').setChecked(false);
        });

        it('is disabled', () => {
          const lockedModelCheckbox = findModelCheckboxes().at(2).findComponent(GlFormCheckbox);

          expect(lockedModelCheckbox.props('value')).toBe(mockChosenModelForFeature.ref);
          expect(findSelectedModelsSummary().text()).toBe('1 model selected');
          expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
        });
      });
    });

    describe('when allow-list is disabled', () => {
      beforeEach(() => {
        findAllowListCheckbox().find('input').setChecked(false);
      });

      it('is enabled', () => {
        expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
      });
    });
  });

  describe('error alert', () => {
    it('does not render when there is no error message', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders the error message when provided', () => {
      createComponent({ props: { errorMessage: 'Something went wrong' } });

      expect(findErrorAlert().text()).toBe('Something went wrong');
    });
  });

  describe('allow-list checkbox', () => {
    it('renders the correct label', () => {
      expect(findAllowListCheckbox().text()).toContain('Restrict to specific models');
    });

    describe('description', () => {
      it('renders the correct text', () => {
        expect(findAllowListCheckbox().text()).toContain(
          'When turned on, users can only use the models selected below, which always includes the currently selected default model. When turned off, users can use all available GitLab managed models (including those added in the future), unless a non-GitLab default model is set as the model for Agentic Chat, in which case users can only use that model.',
        );
      });

      it('includes the GitLab managed models help link', () => {
        expect(findGitLabManagedModelsHelpLink().attributes('href')).toBe(
          '/help/administration/gitlab_duo_self_hosted/_index#gitlab-managed-models',
        );
      });
    });

    describe('when allow-list checkbox is unchecked', () => {
      it('renders available models', () => {
        expect(findModelText()).toHaveLength(mockAvailableModels.length);
      });

      it('does not render per-model checkboxes', () => {
        expect(findModelCheckboxes()).toHaveLength(0);
      });

      it('does not render the locked model indicator', () => {
        expect(findLockedModelIndicator().exists()).toBe(false);
      });
    });

    describe('when allow-list checkbox is checked', () => {
      beforeEach(() => {
        findAllowListCheckbox().find('input').setChecked(true);
      });

      it('renders available models and per-model checkboxes', () => {
        expect(findModelText()).toHaveLength(mockAvailableModels.length);
        expect(findModelCheckboxes()).toHaveLength(mockAvailableModels.length);
      });

      it('checks all model checkboxes by default', () => {
        findModelCheckboxes().wrappers.forEach((checkbox) =>
          expect(checkbox.find('input').element.checked).toBe(true),
        );
      });

      it('disables the locked model checkbox and renders the locked model indicator', () => {
        const lockedModel = findModelItems().find(
          (item) =>
            item.findComponent(GlFormCheckbox).props('value') === mockChosenModelForFeature.ref,
        );
        const lockedModelCheckbox = lockedModel.findComponent(GlFormCheckbox);
        const lockedModelIndicator = lockedModel.find('[data-testid="locked-model-indicator"]');

        expect(lockedModelCheckbox.props('disabled')).toBe(true);
        expect(lockedModelIndicator.exists()).toBe(true);
        expect(lockedModelIndicator.attributes('title')).toBe(
          'This is the currently selected model for Agentic Chat, which is always available to users. To remove it from the list, select a different model.',
        );
      });
    });
  });

  describe('selected models summary', () => {
    it('shows all available models count when allow-list is disabled', () => {
      expect(findSelectedModelsSummary().text()).toBe('All available models (3 models)');
    });

    describe('when allow-list is enabled', () => {
      beforeEach(() => {
        findAllowListCheckbox().find('input').setChecked(true);
      });

      it('shows selected models count', () => {
        expect(findSelectedModelsSummary().text()).toBe('3 models selected');
      });

      it('updates the count when models are unchecked', async () => {
        expect(findSelectedModelsSummary().text()).toBe('3 models selected');

        await findModelCheckboxes().at(0).find('input').setChecked(false);

        expect(findSelectedModelsSummary().text()).toBe('2 models selected');
      });
    });
  });

  describe('select all models toolbar', () => {
    it('does not render the master checkbox when allow-list is disabled', () => {
      expect(findSelectAllCheckbox().exists()).toBe(false);
    });

    describe('when allow-list is enabled', () => {
      beforeEach(() => {
        findAllowListCheckbox().find('input').setChecked(true);
      });

      it('renders the toolbar with the master checkbox', () => {
        expect(findSelectAllToolbar().exists()).toBe(true);
        expect(findSelectAllCheckbox().exists()).toBe(true);
      });

      it('renders the toolbar outside the scrollable list so it stays visible while scrolling', () => {
        expect(findScrollableList().find('[data-testid="select-all-checkbox"]').exists()).toBe(
          false,
        );
        expect(findSelectAllCheckbox().exists()).toBe(true);
      });

      it('is checked when all models are selected', () => {
        const input = findSelectAllCheckbox().element;

        expect(input.checked).toBe(true);
        expect(input.indeterminate).toBe(false);
      });

      it('is indeterminate when only some optional models are selected', async () => {
        await findModelCheckboxByRef('claude_sonnet_4_20250514').setChecked(false);

        const input = findSelectAllCheckbox().element;

        expect(input.checked).toBe(false);
        expect(input.indeterminate).toBe(true);
      });

      it('is unchecked when no optional models are selected', async () => {
        await findModelCheckboxByRef('claude_sonnet_4_20250514').setChecked(false);
        await findModelCheckboxByRef('claude_sonnet_3_7_20250219_vertex').setChecked(false);

        const input = findSelectAllCheckbox().element;

        expect(input.checked).toBe(false);
        expect(input.indeterminate).toBe(false);
      });

      describe('label', () => {
        it('offers to clear the selection when every model is selected', () => {
          expect(findSelectAllToolbar().text()).toContain('Clear all models');
        });

        it('offers to select all models when the selection is partial', async () => {
          await findModelCheckboxByRef('claude_sonnet_4_20250514').setChecked(false);

          expect(findSelectAllToolbar().text()).toContain('Select all models');
        });
      });

      describe('when toggled on from a partial selection', () => {
        beforeEach(async () => {
          await findModelCheckboxByRef('claude_sonnet_4_20250514').setChecked(false);
          await findSelectAllCheckbox().setChecked(true);
        });

        it('selects every model', () => {
          findModelCheckboxes().wrappers.forEach((checkbox) =>
            expect(checkbox.find('input').element.checked).toBe(true),
          );
          expect(findSelectedModelsSummary().text()).toBe('3 models selected');
        });
      });

      describe('when toggled off', () => {
        beforeEach(async () => {
          await findSelectAllCheckbox().setChecked(false);
        });

        it('deselects every model except the locked default', () => {
          expect(findModelCheckboxByRef('claude_sonnet_4_20250514').element.checked).toBe(false);
          expect(findModelCheckboxByRef('claude_sonnet_3_7_20250219_vertex').element.checked).toBe(
            false,
          );
          expect(findModelCheckboxByRef('claude_sonnet_4_6').element.checked).toBe(true);
        });

        it('keeps only the locked model selected and disables Save', () => {
          expect(findSelectedModelsSummary().text()).toBe('1 model selected');
          expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
        });

        it('offers to select all models again', () => {
          expect(findSelectAllToolbar().text()).toContain('Select all models');
        });
      });
    });
  });

  describe('persisted allow-list state seeded from props', () => {
    it('seeds the toggle and selection on mount', () => {
      createComponent({ props: { allowListEnabled: true } });

      expect(findAllowListCheckbox().find('input').element.checked).toBe(true);

      expect(findModelCheckboxByRef('claude_sonnet_4_20250514').element.checked).toBe(true);
      expect(findModelCheckboxByRef('claude_sonnet_3_7_20250219_vertex').element.checked).toBe(
        false,
      );
    });

    it('defaults the toggle off when not persisted as enabled', () => {
      expect(findAllowListCheckbox().find('input').element.checked).toBe(false);
      expect(findModelCheckboxes()).toHaveLength(0);
    });
  });

  describe('available models list', () => {
    it('renders model names', () => {
      mockAvailableModels.forEach((model, index) => {
        expect(findModelNames().at(index).text()).toBe(model.name);
      });
    });

    it('renders model descriptions', () => {
      mockAvailableModels.forEach((model, index) => {
        expect(findModelText().at(index).text()).toContain(model.modelDescription);
      });
    });

    it('renders cost indicators', () => {
      mockAvailableModels.forEach((model, index) => {
        expect(findModelText().at(index).text()).toContain(model.costIndicator);
      });
    });
  });
});
