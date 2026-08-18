import { GlCollapsibleListbox, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import DenyAllowExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_exceptions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EXCEPTION_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('DenyAllowExceptions', () => {
  let wrapper;

  const VALID_EXCEPTIONS_STRING = 'test@project, test1@project';
  const EXCEPTIONS_WITH_DUPLICATES_STRING = 'test@project, test@project, test2@project';

  const VALID_EXCEPTIONS = ['test@project', 'test1@project'];

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowExceptions, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findTextArea = () => wrapper.findComponent(GlFormTextarea);
  const findDuplicateErrorMessage = () => wrapper.findByTestId('error-duplicates-message');
  const findValidationErrorMessage = () => wrapper.findByTestId('error-validation-message');
  const findFormatDescription = () => wrapper.findByTestId('format-description');

  describe('default rendering', () => {
    it('renders default list with no exceptions', () => {
      createComponent();

      expect(findListBox().props('toggleText')).toBe('no exceptions');
      expect(findTextArea().exists()).toBe(false);
    });

    it('selects exception type', () => {
      createComponent();

      findListBox().vm.$emit('select', EXCEPTION_KEY);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPTION_KEY]]);
    });

    it('renders selected license', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      expect(findListBox().props('selected')).toBe(EXCEPTION_KEY);
      expect(findListBox().props('toggleText')).toBe('exceptions');
    });

    it('disables type dropdown', () => {
      createComponent({
        propsData: {
          disabled: true,
        },
      });

      expect(findListBox().props('disabled')).toBe(true);
    });
  });

  describe('selected exceptions', () => {
    it('renders selected exceptions as string', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
          exceptions: VALID_EXCEPTIONS,
        },
      });

      expect(findTextArea().props('value')).toBe(VALID_EXCEPTIONS_STRING);
      expect(findFormatDescription().text()).toBe(
        'Use the format path-to-package@package-version. For multiple packages, separate paths with commas. For example: npm/lodash@4.17.21, maven/org.apache.commons/commons-lang3@3.12.0, pypi/requests',
      );
    });

    it('selects exceptions', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      findTextArea().vm.$emit('input', VALID_EXCEPTIONS_STRING);

      expect(findDuplicateErrorMessage().exists()).toBe(false);
      expect(findValidationErrorMessage().exists()).toBe(false);
      expect(wrapper.emitted('input')).toEqual([[VALID_EXCEPTIONS]]);
    });
  });

  describe('error state', () => {
    it('renders duplicate error', async () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      await findTextArea().vm.$emit('input', EXCEPTIONS_WITH_DUPLICATES_STRING);

      expect(findValidationErrorMessage().exists()).toBe(false);
      expect(findDuplicateErrorMessage().text()).toBe('Duplicates will be removed');
    });
  });

  describe('exceptions placeholder', () => {
    it.each`
      isDeniedList | placeholder
      ${true}      | ${'Specify the packages where this license does not require approval before use'}
      ${false}     | ${'Specify the packages where this license requires approval before use'}
    `('renders correct placeholder for deny and allow list', ({ isDeniedList, placeholder }) => {
      createComponent({
        propsData: {
          isDeniedList,
          exceptionType: EXCEPTION_KEY,
        },
      });

      expect(findTextArea().attributes('placeholder')).toBe(placeholder);
    });
  });
});
