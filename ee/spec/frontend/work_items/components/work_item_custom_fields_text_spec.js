import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormGroup, GlFormInput, GlLink, GlTruncate } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemCustomFieldText from 'ee/work_items/components/work_item_custom_fields_text.vue';
import { ENTER_KEY } from '~/lib/utils/keys';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { CUSTOM_FIELDS_TYPE_NUMBER, CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';
import { newWorkItemId } from '~/work_items/utils';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsText', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: '1-text',
      fieldType: CUSTOM_FIELDS_TYPE_TEXT,
      name: 'Text custom field label',
    },
    value: 'Sample text',
  };

  const mutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      workItemUpdate: {
        workItem: {
          id: defaultWorkItemId,
          widgets: [customFieldsWidgetResponseFactory],
        },
        errors: [],
      },
    },
  });

  const findEditButton = () => wrapper.findComponent('[data-testid="edit-button"]');
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findLink = () => wrapper.findComponent(GlLink);
  const findText = () => wrapper.findComponent(GlTruncate);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');

  const createComponent = ({
    canUpdate = true,
    customField = defaultField,
    mutationHandler = mutationSuccessHandler,
    glFeatures = {},
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldText, {
      apolloProvider: createMockApollo([[updateWorkItemCustomFieldsMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        customField,
        workItemType: 'Task',
        workItemId: defaultWorkItemId,
      },
      provide: {
        glFeatures,
      },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['description'],
        }),
        WorkItemSidebarWidget,
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', () => {
      createComponent();

      expect(wrapper.text()).toContain('Text custom field label');
    });

    it('does not render if custom field is empty', () => {
      createComponent({ customField: {} });

      expect(wrapper.text()).toContain('');
    });

    it('does not render if custom field type is incorrect', () => {
      createComponent({
        customField: {
          id: '1-number',
          fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
          name: 'Number custom field label',
        },
        value: 5,
      });

      expect(wrapper.text()).toContain('');
    });

    it('renders text input when editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();

      expect(findInput().attributes()).toMatchObject({
        maxlength: '1024',
        placeholder: 'Enter text',
      });
    });
  });

  describe('value', () => {
    it('shows None when no text is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 5,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows text when text is set', () => {
      createComponent();

      expect(findLink().exists()).toBe(false);
      expect(findText().props('text')).toContain('Sample text');
    });

    it('shows link value when link is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
        },
      });

      expect(findLink().attributes('href')).toBe(
        'https://gitlab.com/gitlab-org/gitlab/-/work_items/41',
      );
    });

    it('shows character limit warning', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();

      // Generates a string that's > 90% of the CHARACTER_LIMIT
      const longText = 'a'.repeat(1000); // CHARACTER_LIMIT is 1024
      findInput().vm.$emit('input', longText);
      await nextTick();

      expect(findFormGroup().props('description')).toBe('24 characters remaining.');
    });
  });

  describe('updating the value', () => {
    it('does not call "workItemUpdate" mutation when option is selected if is create flow', async () => {
      createComponent({ workItemId: newWorkItemId('Issue') });
      await nextTick();

      const newValue = 'Updated text';

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('sends mutation with correct variables when updating text', async () => {
      createComponent();
      const newValue = 'Updated text';

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              textValue: newValue,
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    describe('when workItemFeaturesField feature flag is enabled', () => {
      it('passes useWorkItemFeatures as true to the mutation', async () => {
        createComponent({ glFeatures: { workItemFeaturesField: true } });
        const newValue = 'Updated text';

        findEditButton().vm.$emit('click');
        await nextTick();
        findInput().vm.$emit('input', newValue);
        findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

        expect(mutationSuccessHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            useWorkItemFeatures: true,
          }),
        );
      });
    });

    it('sends null when clearing the field', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              textValue: null,
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    it('does not call mutation when the input value is the same', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', 'Sample text');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('emits error event when mutation returns an error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorMessage = 'Failed to update';
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemUpdate: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ mutationHandler });

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', 'New text');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', 'New text');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
