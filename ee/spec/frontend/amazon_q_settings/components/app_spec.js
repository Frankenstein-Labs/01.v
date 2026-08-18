import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import App from 'ee/amazon_q_settings/components/app.vue';
import DisconnectSuccessAlert from 'ee/amazon_q_settings/components/disconnect_success_alert.vue';
import DisconnectWarningModal from 'ee/amazon_q_settings/components/disconnect_warning_modal.vue';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { createAndSubmitForm } from '~/lib/utils/create_and_submit_form';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

jest.mock('~/lib/utils/create_and_submit_form');
jest.mock('~/lib/logger');
jest.mock('~/alert');

const TEST_SUBMIT_URL = '/foo/submit/url';
const TEST_DISCONNECT_URL = '/foo/disconnect/url';
const TEST_AMAZON_Q_VALID_ROLE_ARN = 'arn:aws:iam::123456789012:role/valid-role';
const TEST_AMAZON_Q_INVALID_ROLE_ARN = 'arn:aws:iam::test:role/invalid-role';
const TEST_AMAZON_Q_SETTINGS = {
  ready: true,
  availability: 'default_on',
  roleArn: TEST_AMAZON_Q_VALID_ROLE_ARN,
};

describe('ee/amazon_q_settings/components/app.vue', () => {
  let wrapper;
  let mock;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(App, {
      propsData: {
        submitUrl: TEST_SUBMIT_URL,
        disconnectUrl: TEST_DISCONNECT_URL,
        identityProviderPayload: {
          instance_uid: 'instance-uid',
          aws_provider_url: 'https://provider.url',
          aws_audience: 'audience',
        },
        ...props,
      },
      stubs: {
        GlFormInputGroup,
        GlSprintf,
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback', 'validFeedback', 'description'],
        }),
      },
    });
  };

  const event = new Event('submit');

  beforeEach(() => {
    mock = new MockAdapter(axios);
    jest.spyOn(event, 'preventDefault');
  });

  afterEach(() => {
    mock.restore();
  });

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = (label) =>
    findForm()
      .findAllComponents(GlFormGroup)
      .wrappers.find((x) => x.attributes('label') === label);

  const findStatusFormGroup = () => findFormGroup('Status');
  const findSetupFormGroup = () => findFormGroup('Setup');
  const findDisconnectSuccess = () => wrapper.findComponent(DisconnectSuccessAlert);
  const findDisconnectWarning = () => wrapper.findComponent(DisconnectWarningModal);
  const listItems = () => findSetupFormGroup().findAll('ol li').wrappers;
  const listItem = (at) => listItems()[at];

  // arn helpers -----
  const findArnFormGroup = () => findFormGroup("IAM role's ARN");
  const findArnField = () => findArnFormGroup().findComponent(GlFormInput);
  const setArn = (val) => findArnField().vm.$emit('input', val);
  const findDisconnectButton = () => findArnFormGroup().findComponent(GlButton);

  // availability helpers -----
  const findAvailabilityRadioGroup = () =>
    findFormGroup('Availability').findComponent(GlFormRadioGroup);
  const findAvailabilityRadioButtons = () =>
    findAvailabilityRadioGroup()
      .findAllComponents(GlFormRadio)
      .wrappers.map((x) => ({
        value: x.attributes('value'),
        label: x.text(),
      }));

  const findAmazonQCodeReviewCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  const setAvailability = (val) => findAvailabilityRadioGroup().vm.$emit('input', val);
  const setAmazonQCodeReviewEnabled = (val) => {
    setAvailability('default_on');

    const checkbox = findAmazonQCodeReviewCheckbox();
    if (checkbox.exists()) {
      checkbox.vm.$emit('input', val);
    } else {
      throw new Error('Could not find Amazon Q Code Review checkbox');
    }
  };
  // warning helpers -----
  const findAvailabilityWarning = () => findForm().findComponent(GlAlert);
  const findSaveWarning = () => findForm().find('[data-testid=amazon-q-save-warning]');
  const findSaveWarningLink = () => findSaveWarning().find('a');

  // button helpers -----
  const findButton = (text) =>
    findForm()
      .findAllComponents(GlButton)
      .wrappers.find((x) => x.text() === text);
  const findSubmitButton = () => findButton('Save changes');
  const emitSubmitForm = () => findForm().vm.$emit('submit', event);

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('does not render status', () => {
      expect(findStatusFormGroup()).toBeUndefined();
    });

    it('does not render disconnect button', () => {
      expect(findDisconnectButton().exists()).toBe(false);
    });

    it('does not render disconnect sucess', () => {
      expect(findDisconnectSuccess().exists()).toBe(false);
    });

    it('does not show disconnect warning', () => {
      expect(findDisconnectWarning().attributes('visible')).toBeUndefined();
    });

    describe('setup', () => {
      it('renders setup', () => {
        expect(findSetupFormGroup().exists()).toBe(true);

        expect(listItems()).toHaveLength(4);
      });

      it('renders step 1, Create a Q Developer Profile', () => {
        const createQDevProfileStep1 = listItem(0);
        expect(createQDevProfileStep1.text()).toMatchInterpolatedText(
          'Create an Amazon Q Developer profile in the Amazon Q Developer console.',
        );
        expect(createQDevProfileStep1.findComponent(GlLink).text()).toBe(
          'Amazon Q Developer console.',
        );
        expect(createQDevProfileStep1.findComponent(GlLink).attributes('href')).toBe(
          'https://us-east-1.console.aws.amazon.com/amazonq/developer/home?region=us-east-1#/gitlab',
        );
      });

      it('renders step 2', () => {
        const idpStepText = listItem(1).text();
        const idpStepHelpPageLink = listItem(1).findComponent(HelpPageLink);

        expect(idpStepText).toBe(
          'Create an identity provider for this GitLab instance within AWS using the following values. Learn more.',
        );
        expect(idpStepHelpPageLink.props()).toEqual({
          anchor: 'create-an-iam-identity-provider',
          href: 'user/duo_amazon_q/setup.md',
        });
        expect(idpStepHelpPageLink.text()).toEqual('Learn more');
      });

      it('renders identity provider details with clipboard buttons', () => {
        const idpFormFields = listItem(1).findAllComponents(GlFormInputGroup).wrappers;
        const idpClipboardButtons = listItem(1).findAllComponents(ClipboardButton).wrappers;

        expect(idpFormFields[0].props('value')).toEqual('instance-uid');
        expect(idpClipboardButtons[0].props('text')).toEqual('instance-uid');

        expect(idpFormFields[1].props('value')).toEqual('OpenID Connect');
        expect(idpClipboardButtons[1].props('text')).toEqual('OpenID Connect');

        expect(idpFormFields[2].props('value')).toEqual('https://provider.url');
        expect(idpClipboardButtons[2].props('text')).toEqual('https://provider.url');

        expect(idpFormFields[3].props('value')).toEqual('audience');
        expect(idpClipboardButtons[3].props('text')).toEqual('audience');
      });

      it('renders step 3, Create IAM Role', () => {
        const iamStepText = listItem(2).text();
        const iamStepHelpPageLink = listItem(2).findComponent(HelpPageLink);

        expect(iamStepText).toBe(
          'Within your AWS account, create an IAM role for Amazon Q and the relevant identity provider. Learn how to create an IAM role.',
        );
        expect(iamStepHelpPageLink.props()).toEqual({
          anchor: 'create-an-iam-role',
          href: 'user/duo_amazon_q/setup.md',
        });
        expect(iamStepHelpPageLink.text()).toEqual('Learn how to create an IAM role');
      });

      it('renders step 4, Enter the arn', () => {
        const arnStepText = listItem(3).text();

        expect(arnStepText).toEqual("Enter the IAM role's ARN.");
      });
    });

    it('renders arn field', () => {
      expect(findArnFormGroup().exists()).toBe(true);

      const input = findArnField();

      expect(input.attributes('disabled')).toBeUndefined();
      expect(input.attributes()).toMatchObject({
        value: '',
        type: 'text',
        width: 'lg',
        name: 'aws_role',
        placeholder: 'arn:aws:iam::account-id:role/role-name',
      });
    });

    it('renders availability field', () => {
      expect(findAvailabilityRadioGroup().attributes()).toMatchObject({
        checked: 'default_on',
        name: 'availability',
      });
      expect(findAvailabilityRadioButtons()).toEqual([
        {
          label: 'On by default',
          value: 'default_on',
        },
        {
          label: 'Off by default',
          value: 'default_off',
        },
        {
          label: 'Always off',
          value: 'never_on',
        },
      ]);
    });

    it('does not render availability warning', () => {
      expect(findAvailabilityWarning().exists()).toBe(false);
    });

    it('renders save button', () => {
      expect(findSubmitButton().attributes()).toMatchObject({
        type: 'submit',
        variant: 'confirm',
        category: 'primary',
      });
    });

    it('renders save acknowledgement', () => {
      expect(findSaveWarning().text()).toBe(
        'I understand that by selecting Save changes, GitLab creates a service account for Amazon Q and sends its credentials to AWS. Use of the Amazon Q Developer capabilities as part of GitLab Duo with Amazon Q is governed by the AWS Customer Agreement or other written agreement between you and AWS governing your use of AWS services. Amazon Q Developer processes data across all US Regions and makes cross-region API calls when your requests require it.',
      );

      expect(findSaveWarningLink().attributes()).toEqual({
        href: 'http://aws.amazon.com/agreement',
        rel: 'noopener noreferrer',
        target: '_blank',
      });
      expect(findSaveWarningLink().text()).toEqual('AWS Customer Agreement');
    });
  });

  describe('form validations', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not show any validations on load', () => {
      expect(findArnFormGroup().props('state')).toBeNull();
    });

    describe("when IAM role's ARN is empty", () => {
      beforeEach(() => {
        setArn('');
        emitSubmitForm();
      });

      it('shows "required" validation error', () => {
        expect(findArnFormGroup().props()).toMatchObject({
          invalidFeedback: 'This field is required',
          state: false,
        });
      });

      it('does not submit form', () => {
        expect(createAndSubmitForm).not.toHaveBeenCalled();
      });
    });

    describe("when IAM role's ARN is invalid", () => {
      beforeEach(() => {
        setArn(TEST_AMAZON_Q_INVALID_ROLE_ARN);
        emitSubmitForm();
      });

      it('shows "invalid" validation error', () => {
        expect(findArnFormGroup().props()).toMatchObject({
          invalidFeedback: "IAM role's ARN is not valid",
          state: false,
        });
      });

      it('does not submit form', () => {
        expect(createAndSubmitForm).not.toHaveBeenCalled();
      });
    });

    describe('when form is valid', () => {
      beforeEach(() => {
        setArn(TEST_AMAZON_Q_VALID_ROLE_ARN);
        setAvailability('default_off');
        emitSubmitForm();
      });

      it('prevents default', () => {
        expect(event.preventDefault).toHaveBeenCalled();
      });

      it('submits form', () => {
        expect(createAndSubmitForm).toHaveBeenCalledTimes(1);
        expect(createAndSubmitForm).toHaveBeenCalledWith({
          url: TEST_SUBMIT_URL,
          data: {
            auto_review_enabled: false,
            availability: 'default_off',
            role_arn: TEST_AMAZON_Q_VALID_ROLE_ARN,
          },
        });
      });
    });

    describe("when IAM role's ARN is valid and field loses focus", () => {
      beforeEach(() => {
        setArn(TEST_AMAZON_Q_VALID_ROLE_ARN);
        findArnField().vm.$emit('focus');
      });

      it('shows "valid" validation message', () => {
        expect(findArnFormGroup().props()).toMatchObject({
          invalidFeedback: '',
          validFeedback: "IAM role's ARN is valid",
          state: true,
        });
      });
    });
  });

  describe('when ready', () => {
    beforeEach(() => {
      createWrapper({
        amazonQSettings: TEST_AMAZON_Q_SETTINGS,
      });
    });

    it('renders status', () => {
      expect(findStatusFormGroup().exists()).toBe(true);
      expect(findStatusFormGroup().text()).toBe(App.I18N_READY);
    });

    it('does not render setup', () => {
      expect(findSetupFormGroup()).toBeUndefined();
    });

    it('renders disabled arn', () => {
      const input = findArnField();

      expect(input.attributes('disabled')).toBeDefined();
    });

    it('renders disconnect button', () => {
      expect(findDisconnectButton().text()).toBe('Disconnect');
      expect(findDisconnectButton().props()).toMatchObject({
        variant: 'danger',
        category: 'secondary',
        loading: false,
      });
    });

    it('does not render save acknowledgement', () => {
      expect(findSaveWarning().exists()).toBe(false);
    });

    it('when disconnect button is pressed, shows warning', async () => {
      expect(findDisconnectWarning().attributes('visible')).toBeUndefined();

      await findDisconnectButton().vm.$emit('click');

      expect(findDisconnectWarning().attributes('visible')).toBeDefined();
    });

    describe('when submitting', () => {
      describe('when auto review enabled', () => {
        beforeEach(() => {
          setArn(TEST_AMAZON_Q_VALID_ROLE_ARN);
          setAvailability('default_on');
          setAmazonQCodeReviewEnabled(true);
          emitSubmitForm();
        });

        it('submits form with auto review enabled', () => {
          expect(createAndSubmitForm).toHaveBeenCalledTimes(1);
          expect(createAndSubmitForm).toHaveBeenCalledWith({
            url: TEST_SUBMIT_URL,
            data: {
              auto_review_enabled: true,
              availability: 'default_on',
            },
          });
        });
      });

      describe('when auto review disabled', () => {
        beforeEach(async () => {
          setAvailability('default_off');
          await nextTick();
          findForm().vm.$emit('submit', new Event('submit'));
        });

        it('submits form with auto review disabled', () => {
          expect(createAndSubmitForm).toHaveBeenCalledTimes(1);
          expect(createAndSubmitForm).toHaveBeenCalledWith({
            url: TEST_SUBMIT_URL,
            data: {
              auto_review_enabled: false,
              availability: 'default_off',
            },
          });
        });
      });
    });

    describe('when disconnect confirmed', () => {
      beforeEach(async () => {
        mock.onPost(TEST_DISCONNECT_URL).replyOnce(200);

        await findDisconnectWarning().vm.$emit('submit');
      });

      it('shows loading on disconnect button', () => {
        expect(findDisconnectButton().props('loading')).toBe(true);
      });

      it('after loading, shows success state', async () => {
        expect(findDisconnectSuccess().exists()).toBe(false);
        expect(findArnField().attributes('value')).toBe(TEST_AMAZON_Q_VALID_ROLE_ARN);
        expect(findStatusFormGroup().exists()).toBe(true);

        await axios.waitForAll();

        expect(findDisconnectSuccess().exists()).toBe(true);
        expect(findArnField().attributes('value')).toBe('');
        expect(findStatusFormGroup()).toBeUndefined();
      });
    });

    describe('when disconnect fails', () => {
      beforeEach(async () => {
        mock.onPost(TEST_DISCONNECT_URL).replyOnce(400);

        await findDisconnectWarning().vm.$emit('submit');
        await axios.waitForAll();
      });

      it('success is not visible', () => {
        expect(findDisconnectSuccess().exists()).toBe(false);
      });

      it('ready status is still rendered', () => {
        expect(findStatusFormGroup().exists()).toBe(true);
      });

      it('disconnect button is not loading', () => {
        expect(findDisconnectButton().props('loading')).toBe(false);
      });
    });

    describe('when disconnect fails with UUID mismatch', () => {
      beforeEach(async () => {
        mock.onPost(TEST_DISCONNECT_URL).replyOnce(422, {
          error_type: 'uuid_mismatch',
        });

        await findDisconnectWarning().vm.$emit('submit');
        await axios.waitForAll();
      });

      it('shows UUID mismatch error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message:
            'Amazon Q failed to disconnect because of a mismatch with the GitLab instance UUID. This issue typically occurs when the GitLab instance has been restored or migrated. %{linkStart}View troubleshooting information%{linkEnd}.',
          messageLinks: {
            link: {
              href: '/help/user/duo_amazon_q/setup.md#troubleshooting',
              target: '_blank',
              rel: 'noopener noreferrer',
            },
          },
        });
      });
    });
  });

  describe('availability warnings', () => {
    it.each`
      orig             | value            | expected
      ${'default_off'} | ${'default_off'} | ${''}
      ${'default_off'} | ${'never_on'}    | ${App.I18N_WARNING_NEVER_ON}
      ${'default_off'} | ${'default_on'}  | ${''}
      ${'never_on'}    | ${'never_on'}    | ${''}
      ${'never_on'}    | ${'default_off'} | ${App.I18N_WARNING_OFF_BY_DEFAULT}
      ${'never_on'}    | ${'default_on'}  | ${''}
      ${'default_on'}  | ${'default_on'}  | ${''}
      ${'default_on'}  | ${'default_off'} | ${App.I18N_WARNING_OFF_BY_DEFAULT}
      ${'default_on'}  | ${'never_on'}    | ${App.I18N_WARNING_NEVER_ON}
    `('from $orig to $value', async ({ orig, value, expected }) => {
      createWrapper({
        amazonQSettings: {
          ...TEST_AMAZON_Q_SETTINGS,
          availability: orig,
        },
      });

      expect(findAvailabilityWarning().exists()).toBe(false);

      setAvailability(value);
      await nextTick();

      if (expected) {
        expect(findAvailabilityWarning().props()).toMatchObject({
          dismissible: false,
          variant: 'warning',
        });
        expect(findAvailabilityWarning().text()).toBe(expected);
      } else {
        expect(findAvailabilityWarning().exists()).toBe(false);
      }
    });
  });
});
