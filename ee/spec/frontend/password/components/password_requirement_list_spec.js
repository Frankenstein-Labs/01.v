import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import { THOUSAND } from '~/lib/utils/constants';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import {
  RED_TEXT_CLASS,
  GREEN_TEXT_CLASS,
  INVALID_INPUT_CLASS,
  INVALID_FORM_CLASS,
  I18N,
  LENGTH,
  COMMON,
  USER_INFO,
} from 'ee/password/constants';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { PASSWORD_COMPLEXITY_PATH } from 'ee/api/users_api';
import PasswordRequirementList from 'ee/password/components/password_requirement_list.vue';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('Password requirement list component', () => {
  let wrapper;
  let mockAxios;

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  const PASSWORD_INPUT_CLASS = 'js-password-complexity-validation';
  const findStatusIcon = (ruleType) => wrapper.findByTestId(`password-${ruleType}-status-icon`);
  const findGlIcon = (statusIcon) => findStatusIcon(statusIcon).findComponent(GlIcon);
  const findRuleTextsByClass = (colorClassName) =>
    wrapper.findAllByTestId('password-rule-text').filter((c) => c.classes(colorClassName));
  const findPasswordInputElement = () => document.querySelector(`.${PASSWORD_INPUT_CLASS}`);
  const findForm = () => findPasswordInputElement().form;
  const findSubmitButton = () => findForm().querySelector('[type="submit"]');
  const ruleTypes = ['number', 'lowercase', 'uppercase', 'symbol'];

  const createComponent = ({ props = {} } = {}) => {
    const passwordInputElement = findPasswordInputElement();
    wrapper = extendedWrapper(
      shallowMount(PasswordRequirementList, {
        propsData: {
          passwordInputElement,
          ruleTypes,
          allowNoPassword: false,
          ...props,
        },
      }),
    );
  };

  beforeEach(() => {
    setHTMLFixture(`
      <form>
        <input id="new_user_first_name" name="new_user[first_name]" type="text">
        <input autocomplete="new-password" class="form-control gl-form-input ${PASSWORD_INPUT_CLASS}" type="password" name="new_user[password]" id="new_user_password">
        <input type="submit" name="commit" value="Submit">
      </form>
    `);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('when empty password is not allowed', () => {
    beforeEach(() => {
      createComponent();

      findPasswordInputElement().value = '';
    });

    it('should show when password is empty', () => {
      const passwordRules = wrapper.findByTestId('password-requirement-list');
      expect(passwordRules.isVisible()).toBe(true);
    });

    it('should not allow submit when password is empty', () => {
      findSubmitButton().dispatchEvent(new Event('click'));
      expect(findPasswordInputElement().classList.contains(INVALID_INPUT_CLASS)).toBe(true);
    });
  });

  describe('when empty password is allowed', () => {
    beforeEach(() => {
      createComponent({
        props: {
          allowNoPassword: true,
        },
      });
      findPasswordInputElement().value = '';
    });
    it('should hide when password is empty', () => {
      const passwordRules = wrapper.findByTestId('password-requirement-list');
      expect(passwordRules.isVisible()).toBe(false);
    });

    it('should allow submit when password is empty', () => {
      findSubmitButton().dispatchEvent(new Event('click'));
      expect(findPasswordInputElement().classList.contains(INVALID_INPUT_CLASS)).toBe(false);
    });
  });

  describe.each`
    password  | matchNumber | matchLowerCase | matchUpperCase | matchSymbol
    ${'1'}    | ${true}     | ${false}       | ${false}       | ${false}
    ${'a'}    | ${false}    | ${true}        | ${false}       | ${false}
    ${'A'}    | ${false}    | ${false}       | ${true}        | ${false}
    ${'!'}    | ${false}    | ${false}       | ${false}       | ${true}
    ${'1a'}   | ${true}     | ${true}        | ${false}       | ${false}
    ${'٤āÁ.'} | ${true}     | ${true}        | ${true}        | ${true}
  `(
    'password $password',
    ({ password, matchNumber, matchLowerCase, matchUpperCase, matchSymbol }) => {
      beforeEach(() => {
        createComponent();

        const passwordInputElement = findPasswordInputElement();
        passwordInputElement.value = password;
        passwordInputElement.dispatchEvent(new Event('input'));
      });
      const resultList = [matchNumber, matchLowerCase, matchUpperCase, matchSymbol];
      const ruleAndResultTable = ruleTypes.map((ruleType, index) => [ruleType, resultList[index]]);

      describe.each(ruleAndResultTable)('match %s %s', (ruleType, result) => {
        it(`should show icon correctly on ${ruleType} line`, async () => {
          await nextTick();

          const glIcon = findGlIcon(ruleType);

          expect(glIcon.classes(GREEN_TEXT_CLASS)).toBe(result);
          expect(glIcon.props('name')).toBe(result ? 'check' : 'status_created_borderless');
          expect(glIcon.props('size')).toBe(result ? 16 : 12);

          findSubmitButton().dispatchEvent(new Event('click'));

          await nextTick();

          expect(glIcon.classes(RED_TEXT_CLASS)).toBe(!result);
          expect(glIcon.props('name')).toBe(result ? 'check' : 'close');
          expect(glIcon.props('size')).toBe(16);
        });

        it(`should aria label correctly on ${ruleType} line`, async () => {
          const submitButton = findSubmitButton();

          await nextTick();

          expect(findStatusIcon(ruleType).attributes('aria-label')).toBe(
            result ? I18N.PASSWORD_SATISFIED : I18N.PASSWORD_TO_BE_SATISFIED,
          );
          submitButton.dispatchEvent(new Event('click'));

          await nextTick();

          expect(findStatusIcon(ruleType).attributes('aria-label')).toBe(
            result ? I18N.PASSWORD_SATISFIED : I18N.PASSWORD_NOT_SATISFIED,
          );
        });
      });

      it('should show red text on rule and red border on input after submit', async () => {
        const passwordInputElement = findPasswordInputElement();
        const form = findForm();
        const submitButton = findSubmitButton();
        submitButton.dispatchEvent(new Event('click'));

        await nextTick();

        const unMatchedNumber = resultList.filter((isMatched) => isMatched === false).length;

        if (unMatchedNumber > 0) {
          expect(passwordInputElement.classList.contains(INVALID_INPUT_CLASS)).toBe(true);
          expect(form.classList.contains(INVALID_FORM_CLASS)).toBe(true);
        }
        expect(findRuleTextsByClass(RED_TEXT_CLASS)).toHaveLength(unMatchedNumber);
        expect(findRuleTextsByClass(GREEN_TEXT_CLASS)).toHaveLength(
          wrapper.vm.ruleTypes.length - unMatchedNumber,
        );
      });
    },
  );

  describe('password complexity rules', () => {
    beforeEach(() => {
      createComponent({ props: { ruleTypes: [LENGTH, COMMON, USER_INFO] } });
    });

    it('shows the list as secondary text', () => {
      expect(
        wrapper.findByTestId('password-requirement-list').classes().includes('gl-text-subtle'),
      ).toBe(true);
    });

    describe('when there are errors', () => {
      const password = '1111111';

      beforeEach(() => {
        mockAxios
          .onPost(PASSWORD_COMPLEXITY_PATH, { user: { password, first_name: '' } })
          .reply(HTTP_STATUS_OK, { [COMMON]: true, [USER_INFO]: true });
      });

      it('shows red text on rule and red border on input after submit', async () => {
        const passwordInputElement = findPasswordInputElement();

        passwordInputElement.value = password;
        passwordInputElement.dispatchEvent(new Event('input'));

        jest.advanceTimersByTime(THOUSAND);
        await waitForPromises();

        findSubmitButton().dispatchEvent(new Event('click'));

        await nextTick();

        const errorRules = findRuleTextsByClass(RED_TEXT_CLASS);

        expect(errorRules).toHaveLength(3);
        expect(errorRules.at(0).text()).toBe('Must be between 8-128 characters');
        expect(errorRules.at(1).text()).toBe('Cannot use common phrases (e.g. "password")');
        expect(errorRules.at(2).text()).toBe('Cannot include your name, username, or email');
        expect(findRuleTextsByClass(GREEN_TEXT_CLASS)).toHaveLength(0);
        expect(findForm().classList.contains(INVALID_FORM_CLASS)).toBe(true);
        expect(passwordInputElement.classList.contains(INVALID_INPUT_CLASS)).toBe(true);
      });
    });

    describe('when there are no errors', () => {
      const password = '11111111';

      beforeEach(() => {
        mockAxios
          .onPost(PASSWORD_COMPLEXITY_PATH, { user: { password, first_name: '' } })
          .reply(HTTP_STATUS_OK, { [COMMON]: false, [USER_INFO]: false });
      });

      it('shows green text on rule', async () => {
        const passwordInputElement = findPasswordInputElement();

        passwordInputElement.value = password;
        passwordInputElement.dispatchEvent(new Event('input'));

        jest.advanceTimersByTime(THOUSAND);
        await waitForPromises();

        const validRules = findRuleTextsByClass(GREEN_TEXT_CLASS);

        expect(validRules).toHaveLength(3);
        expect(validRules.at(0).text()).toBe('Must be between 8-128 characters');
        expect(validRules.at(1).text()).toBe('Cannot use common phrases (e.g. "password")');
        expect(validRules.at(2).text()).toBe('Cannot include your name, username, or email');
        expect(findRuleTextsByClass(RED_TEXT_CLASS)).toHaveLength(0);
        expect(passwordInputElement.classList.contains(INVALID_INPUT_CLASS)).toBe(false);
      });
    });

    describe('when password complexity validation failed', () => {
      const password = '11111111';

      beforeEach(() => {
        mockAxios.onPost(PASSWORD_COMPLEXITY_PATH).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('calls createAlert with error message', async () => {
        const passwordInputElement = findPasswordInputElement();

        passwordInputElement.value = password;
        passwordInputElement.dispatchEvent(new Event('input'));

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to validate password due to server or connection issue. Try again.',
        });
      });
    });
  });
});
