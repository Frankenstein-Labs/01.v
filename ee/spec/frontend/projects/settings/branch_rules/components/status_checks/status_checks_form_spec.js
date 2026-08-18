import { nextTick } from 'vue';
import { GlButton, GlFormGroup, GlFormInput } from '@gitlab/ui';
import StatusChecksForm from 'ee/projects/settings/branch_rules/components/status_checks/status_checks_form.vue';
import { SHARED_SECRET_MAX_LENGTH } from 'ee/status_checks/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(StatusChecksForm, {
      propsData,
      stubs: {
        GlButton,
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback', 'description', 'disabled'],
        }),
        GlFormInput: stubComponent(GlFormInput, {
          props: ['state', 'disabled', 'value', 'placeholder'],
          template: `<input />`,
        }),
      },
    });
  };
  const findNameInput = () => wrapper.findComponentByTestId('service-name-input');
  const findNameValidation = () => wrapper.findComponentByTestId('service-name-group');
  const findSaveChangesButton = () => wrapper.findComponentByTestId('save-btn');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-btn');
  const findUrlInput = () => wrapper.findComponentByTestId('api-url-input');
  const findUrlValidation = () => wrapper.findComponentByTestId('api-url-group');
  const findSharedSecretInput = () => wrapper.findComponentByTestId('shared-secret-input');
  const findSharedSecretGroup = () => wrapper.findComponentByTestId('shared-secret-group');
  const findOverrideHmacButton = () => wrapper.findComponentByTestId('override-hmac');
  const findValidations = () => [findNameValidation(), findUrlValidation()];
  const inputsAreValid = () => findValidations().every((x) => x.props('state'));

  describe('initialization', () => {
    it('shows empty inputs when no initial data is given', () => {
      createComponent({ selectedStatusCheck: null });
      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe('');
      expect(findUrlInput().props('value')).toBe('');
    });
    it('shows filled inputs when initial data is given', () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[0] });
      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe(statusChecksRulesMock[0].name);
      expect(findUrlInput().props('value')).toBe(statusChecksRulesMock[0].externalUrl);
    });
  });

  describe('emits events', () => {
    beforeEach(() => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[0] });
    });
    it('emits save event when save button is clicked', () => {
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
            sharedSecret: '',
          },
        ],
      ]);
    });
    it('emits close event when cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(wrapper.emitted('close-status-check-drawer')).toEqual([[]]);
    });
  });

  describe('validations', () => {
    it('shows the validation messages if invalid on submission', async () => {
      createComponent({
        selectedStatusCheck: null,
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toBe(undefined);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Please provide a name.');
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it('shows the invalid URL error if the URL is invalid', async () => {
      createComponent({ selectedStatusCheck: { name: 'QA', externalUrl: 'not//valid-utl' } });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toBe(undefined);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it('shows the serverValidationErrors if given', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
        serverValidationErrors: [
          'External url has already been taken',
          'Name has already been taken',
        ],
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
            sharedSecret: '',
          },
        ],
      ]);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Name already exists.');
      expect(findUrlValidation().props('invalidFeedback')).toBe('External API is already in use.');
    });

    it('does not show any errors if the values are valid', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
            sharedSecret: '',
          },
        ],
      ]);
      await nextTick();
      expect(inputsAreValid()).toBe(true);
    });

    it('shows invalid shared secret error when secret exceeds max length', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
      });
      const longSecret = 'a'.repeat(SHARED_SECRET_MAX_LENGTH + 1);
      await findSharedSecretInput().vm.$emit('input', longSecret);

      await findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('save-status-check-change')).toBeUndefined();
      expect(findSharedSecretGroup().props('state')).toBe(false);
      expect(findSharedSecretGroup().props('invalidFeedback')).toBe(
        'Shared secret cannot be longer than 255 characters.',
      );
    });

    it('allows valid shared secret within max length', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
      });
      const validSecret = 'a'.repeat(SHARED_SECRET_MAX_LENGTH);
      await findSharedSecretInput().vm.$emit('input', validSecret);

      await findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
            sharedSecret: validSecret,
          },
        ],
      ]);
    });
  });

  describe('HMAC override functionality', () => {
    it.each`
      hmacEnabled | mockIndex | expected
      ${false}    | ${0}      | ${false}
      ${true}     | ${1}      | ${true}
    `('shows override button: $expected when hmac is $hmacEnabled', ({ mockIndex, expected }) => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[mockIndex] });
      expect(findOverrideHmacButton().exists()).toBe(expected);
    });

    it('disables shared secret input when hmac is enabled and override is not clicked', () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[1] });
      expect(findSharedSecretInput().props('disabled')).toBe(true);
      expect(findSharedSecretInput().props('placeholder')).toBe('••••••');
    });

    it('enables shared secret input after clicking override button', async () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[1] });
      expect(findSharedSecretInput().props('disabled')).toBe(true);
      await findOverrideHmacButton().vm.$emit('click');
      expect(findSharedSecretInput().props('disabled')).toBe(false);
      expect(findSharedSecretInput().props('placeholder')).toBe('');
    });

    it('disables override button after it is clicked', async () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[1] });
      expect(findOverrideHmacButton().props('disabled')).toBe(false);
      await findOverrideHmacButton().vm.$emit('click');
      expect(findOverrideHmacButton().props('disabled')).toBe(true);
    });

    it('shows correct description for hmac', async () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[1] });
      expect(findSharedSecretGroup().props('description')).toBe(
        'A secret is currently configured for this status check.',
      );

      await findOverrideHmacButton().vm.$emit('click');
      expect(findSharedSecretGroup().props('description')).toBe(
        'Enter a new value to overwrite the current secret.',
      );
    });
  });
});
