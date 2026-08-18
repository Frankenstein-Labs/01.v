import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  PRESET_OPTIONS_BLANK,
  PRESET_OPTIONS_DEFAULT,
} from 'ee/analytics/cycle_analytics/vsa_settings/constants';
import CustomStageFields from 'ee/analytics/cycle_analytics/vsa_settings/components/custom_stage_fields.vue';
import DefaultStageFields from 'ee/analytics/cycle_analytics/vsa_settings/components/default_stage_fields.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import ValueStreamFormContentActions from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import createValueStream from 'ee/analytics/cycle_analytics/vsa_settings/graphql/create_value_stream.mutation.graphql';
import updateValueStream from 'ee/analytics/cycle_analytics/vsa_settings/graphql/update_value_stream.mutation.graphql';
import { customStageEvents as stageEvents } from '../../mock_data';
import { defaultStages, mockChangeValueStreamResponse } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

describe('ValueStreamFormContent', () => {
  let wrapper = null;
  let trackingSpy = null;

  const mockValueStream = { id: 13 };
  const valueStreamGid = 'gid://gitlab/ValueStream/13';
  const fullPath = 'fake/group/path';
  const streamName = 'Cool stream';

  const customStage = {
    name: 'Coolest beans stage',
    id: 'gid://gitlab/ValueStream::Stage/10',
    custom: true,
    startEventIdentifier: 'issue_first_mentioned_in_commit',
    endEventIdentifier: 'issue_first_added_to_board',
  };

  const initialData = {
    ...mockValueStream,
    stages: [customStage],
    name: 'Editable value stream',
  };

  const createWrapper = ({
    props = {},
    provide = {},
    createProvider = jest.fn().mockResolvedValue(mockChangeValueStreamResponse),
    updateProvider = jest.fn().mockResolvedValue(mockChangeValueStreamResponse),
  } = {}) => {
    const apolloProvider = createMockApollo([
      [createValueStream, createProvider],
      [updateValueStream, updateProvider],
    ]);

    wrapper = shallowMountExtended(ValueStreamFormContent, {
      apolloProvider,
      provide: {
        vsaPath: '/mockPath',
        fullPath,
        stageEvents,
        defaultStages,
        valueStreamGid: '',
        ...provide,
      },
      propsData: props,
      stubs: {
        CrudComponent,
      },
    });
  };

  const findAddStageBtn = () => wrapper.findComponentByTestId('add-button');
  const findFormActions = () => wrapper.findComponent(ValueStreamFormContentActions);
  const findDefaultStages = () => wrapper.findAllComponents(DefaultStageFields);
  const findCustomStages = () => wrapper.findAllComponents(CustomStageFields);
  const findLastCustomStage = () => findCustomStages().wrappers.at(-1);

  const findPresetSelector = () => wrapper.findComponentByTestId('vsa-preset-selector');
  const findRestoreButton = () => wrapper.findComponentByTestId('vsa-reset-button');
  const findHiddenStages = () => wrapper.findAllByTestId('vsa-hidden-stage').wrappers;
  const findNameFormGroup = () => wrapper.findByTestId('create-value-stream-name');
  const findNameInput = () => wrapper.findComponentByTestId('create-value-stream-name-input');

  const clickSubmit = () => findFormActions().vm.$emit('click-primary-action');
  const clickAddStage = async () => {
    findAddStageBtn().vm.$emit('click');
    await nextTick();
  };
  const expectStageTransitionKeys = (stages) =>
    stages.forEach((stage) => expect(stage.transitionKey).toContain('stage-'));

  const changeToDefaultStages = () =>
    findPresetSelector().vm.$emit('input', PRESET_OPTIONS_DEFAULT);
  const changeToCustomStages = () => findPresetSelector().vm.$emit('input', PRESET_OPTIONS_BLANK);

  describe('when creating value stream', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has the form actions', () => {
      expect(findFormActions().props()).toMatchObject({
        isLoading: false,
      });
    });

    describe('Preset selector', () => {
      it('has the preset button', () => {
        expect(findPresetSelector().exists()).toBe(true);
      });

      it('will toggle between the blank and default templates', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStages.length);
        expect(findCustomStages()).toHaveLength(0);

        await changeToCustomStages();

        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(1);

        await changeToDefaultStages();

        expect(findDefaultStages()).toHaveLength(defaultStages.length);
        expect(findCustomStages()).toHaveLength(0);
      });

      it('does not clear name when toggling templates', async () => {
        await findNameInput().vm.$emit('input', initialData.name);

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await changeToCustomStages();

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await changeToDefaultStages();

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('each stage has a transition key when toggling', async () => {
        await changeToCustomStages();

        expectStageTransitionKeys(wrapper.vm.stages);

        await changeToDefaultStages();

        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('does not display any hidden stages', () => {
        expect(findHiddenStages()).toHaveLength(0);
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders add stage action correctly', () => {
        expect(findAddStageBtn().props()).toMatchObject({
          category: 'primary',
          variant: 'default',
          disabled: false,
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStages.length);
        expect(findCustomStages()).toHaveLength(0);

        await clickAddStage();

        expect(findDefaultStages()).toHaveLength(defaultStages.length);
        expect(findCustomStages()).toHaveLength(1);
      });

      it('each stage has a transition key', () => {
        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('scrolls to the last stage after adding', async () => {
        await clickAddStage();

        expect(findLastCustomStage().element.scrollIntoView).toHaveBeenCalledWith({
          behavior: 'smooth',
        });
      });
    });

    describe('field validation', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('validates existing fields when clicked', async () => {
        expect(findNameFormGroup().attributes('invalid-feedback')).toBe(undefined);

        await clickAddStage();

        expect(findNameFormGroup().attributes('invalid-feedback')).toBe('Name is required');
      });

      it('does not allow duplicate stage names', async () => {
        const [firstDefaultStage] = defaultStages;
        await findNameInput().vm.$emit('input', streamName);

        await clickAddStage();
        await findCustomStages().at(0).vm.$emit('input', {
          field: 'name',
          value: firstDefaultStage.name,
        });

        // Trigger the field validation
        await clickAddStage();

        expect(findCustomStages().at(0).props().errors.name).toEqual(['Stage name already exists']);
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitted successfully', () => {
        let createProvider;

        beforeEach(async () => {
          createProvider = jest.fn().mockResolvedValue(mockChangeValueStreamResponse);
          createWrapper({ createProvider });

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();

          await waitForPromises();
        });

        it('sends a create request', () => {
          expect(createProvider).toHaveBeenCalledTimes(1);
          expect(createProvider).toHaveBeenCalledWith({
            fullPath,
            name: streamName,
            stages: [
              { name: 'issue', custom: false },
              { name: 'plan', custom: false },
              { name: 'code', custom: false },
            ],
          });
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'create_value_stream',
          });
        });

        it('form header should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the new value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith('/mockPath?value_stream_id=13', [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${streamName}' Value Stream has been successfully created.`,
              variant: 'success',
            },
          ]);
        });
      });

      describe('form submitted with errors', () => {
        let createProvider;

        beforeEach(async () => {
          createProvider = jest.fn().mockResolvedValue({
            data: {
              valueStreamChange: {
                valueStream: { id: null },
                errors: ['KABOOM'],
              },
            },
          });
          createWrapper({ createProvider });

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();

          await waitForPromises();
        });

        it('sends a create request', () => {
          expect(createProvider).toHaveBeenCalledTimes(1);
        });

        it('does not redirect to the new value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders an alert error', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: 'KABOOM.' });
        });
      });

      describe('form submission fails', () => {
        let mockError;
        let createProvider;

        beforeEach(async () => {
          mockError = new Error('KABOOM');
          createProvider = jest.fn().mockRejectedValue(mockError);

          createWrapper({ createProvider });

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();

          await waitForPromises();
        });

        it('sends a create request', () => {
          expect(createProvider).toHaveBeenCalledTimes(1);
        });

        it('does not clear the name field', () => {
          expect(findNameInput().attributes('value')).toBe(streamName);
        });

        it('does not redirect to the new value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders an alert error', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'An error occurred while creating the custom value stream. Try again.',
            error: mockError,
            captureError: true,
          });
        });
      });
    });
  });

  describe('when editing value stream', () => {
    const stageCount = initialData.stages.length;
    beforeEach(() => {
      createWrapper({
        provide: {
          valueStreamGid,
        },
        props: {
          initialData,
        },
      });
    });

    it('does not have the preset button', () => {
      expect(findPresetSelector().exists()).toBe(false);
    });

    it('does not display any hidden stages', () => {
      expect(findHiddenStages()).toHaveLength(0);
    });

    it('each stage has a transition key', () => {
      expectStageTransitionKeys(wrapper.vm.stages);
    });

    describe('restore defaults button', () => {
      it('only renders when there are pending changes', async () => {
        expect(findRestoreButton().exists()).toBe(false);

        await findNameInput().vm.$emit('input', 'new name');

        expect(findRestoreButton().exists()).toBe(true);

        await findNameInput().vm.$emit('input', initialData.name);

        expect(findRestoreButton().exists()).toBe(false);
      });

      it('restores the original name', async () => {
        const newName = 'name';

        await findNameInput().vm.$emit('input', newName);

        expect(findNameInput().attributes('value')).toBe(newName);

        await findRestoreButton().vm.$emit('click');

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('resets the value stream stages', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);

        await findRestoreButton().vm.$emit('click');

        expect(findCustomStages()).toHaveLength(stageCount);
      });

      it('restores a changed stage name', async () => {
        const newName = 'name';
        const stage = findCustomStages().at(0);

        await stage.vm.$emit('input', {
          field: 'name',
          value: newName,
        });

        expect(stage.props().stage.name).toBe(newName);

        await findRestoreButton().vm.$emit('click');

        expect(stage.props().stage.name).toBe(initialData.stages[0].name);
      });
    });

    describe('with hidden stages', () => {
      const hiddenStages = defaultStages.map((s) => ({ ...s, hidden: true }));

      beforeEach(() => {
        createWrapper({
          provide: {
            valueStreamGid,
          },
          props: {
            initialData: { ...initialData, stages: [...initialData.stages, ...hiddenStages] },
          },
        });
      });

      it('displays hidden each stage', () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);

        findHiddenStages().forEach((s) => {
          expect(s.text()).toContain('Restore stage');
        });
      });

      it('when `Restore stage` is clicked, the stage is restored', async () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);
        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(stageCount);

        const button = findHiddenStages()[0].findComponent('[data-testid="stage-action-restore"]');
        await button.vm.$emit('click');

        expect(findHiddenStages()).toHaveLength(hiddenStages.length - 1);
        expect(findDefaultStages()).toHaveLength(1);
        expect(findCustomStages()).toHaveLength(stageCount);
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            valueStreamGid,
          },
          props: {
            initialData,
          },
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);
      });

      it('validates existing fields when clicked', async () => {
        expect(findNameInput().props().state).toBe(true);

        await findNameInput().vm.$emit('input', '');
        await clickAddStage();

        expect(findNameInput().props().state).toBe(false);
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitted successfully', () => {
        let updateProvider;

        beforeEach(() => {
          updateProvider = jest.fn().mockResolvedValue(mockChangeValueStreamResponse);
          createWrapper({
            updateProvider,
            provide: {
              valueStreamGid,
            },
            props: {
              initialData,
            },
          });

          clickSubmit();
          return waitForPromises();
        });

        it('sends an update request', () => {
          expect(updateProvider).toHaveBeenCalledTimes(1);
          expect(updateProvider).toHaveBeenCalledWith({
            id: valueStreamGid,
            name: initialData.name,
            stages: [
              {
                ...customStage,
                startEventIdentifier: 'ISSUE_FIRST_MENTIONED_IN_COMMIT',
                endEventIdentifier: 'ISSUE_FIRST_ADDED_TO_BOARD',
              },
            ],
          });
        });

        it('form actions should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the updated value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith('/mockPath?value_stream_id=13', [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${initialData.name}' Value Stream has been successfully saved.`,
              variant: 'success',
            },
          ]);
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'edit_value_stream',
          });
        });
      });

      describe('form submitted with errors', () => {
        let updateProvider;

        beforeEach(() => {
          updateProvider = jest.fn().mockResolvedValue({
            data: {
              valueStreamChange: {
                valueStream: { id: null },
                errors: ['KABOOM'],
              },
            },
          });

          createWrapper({
            updateProvider,
            provide: {
              valueStreamGid,
            },
            props: {
              initialData,
            },
          });

          clickSubmit();
          return waitForPromises();
        });

        it('sends an update request', () => {
          expect(updateProvider).toHaveBeenCalledTimes(1);
        });

        it('does not redirect to the new value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders an alert error', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: 'KABOOM.' });
        });
      });

      describe('form submission fails', () => {
        let mockError;
        let updateProvider;

        beforeEach(() => {
          mockError = new Error('KABOOM');
          updateProvider = jest.fn().mockRejectedValue(mockError);

          createWrapper({
            updateProvider,
            provide: {
              valueStreamGid,
            },
            props: {
              initialData,
            },
          });

          clickSubmit();
          return waitForPromises();
        });

        it('sends an update request', () => {
          expect(updateProvider).toHaveBeenCalledTimes(1);
        });

        it('does not clear the name field', () => {
          const { name } = initialData;

          expect(findNameInput().attributes('value')).toBe(name);
        });

        it('does not redirect to the value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders an alert error', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'An error occurred while updating the custom value stream. Try again.',
            error: mockError,
            captureError: true,
          });
        });
      });
    });
  });
});
